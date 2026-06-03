import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/generation_engine.dart';
import 'package:grabbit/core/ai/generation_model.dart';
import 'package:grabbit/core/ai/generation_provider.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/structured_generation.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/ai/data/chat_repository.dart';
import 'package:grabbit/features/ai/data/rag_context.dart';
import 'package:grabbit/features/ai/data/rag_retriever.dart';
import 'package:grabbit/features/ai/presentation/ask_chat.dart';
import 'package:grabbit/features/ai/presentation/ask_controller.dart';

/// Generation engine that streams a fixed reply (or throws).
class FakeGenerationEngine implements GenerationEngine {
  FakeGenerationEngine({this.output = 'It was great [1].', this.fail = false});
  final String output;
  final bool fail;
  final List<String> prompts = [];

  @override
  GenerationModel get model => qwen3_0_6b;
  @override
  bool get isAvailable => true;
  @override
  Future<bool> ensureReady() async => true;
  @override
  Future<void> downloadModel({void Function(double)? onProgress}) async {}
  @override
  Stream<String> generate(String prompt, {String? systemPrompt}) async* {
    prompts.add(prompt);
    if (fail) {
      throw const InferenceException(InferenceErrorCode.generateFailed, 'boom');
    }
    yield output;
  }

  @override
  Future<StructuredResult> generateStructured(
    List<StructuredToolDef> toolDefs,
    String prompt, {
    String? systemPrompt,
  }) => throw UnimplementedError();
  @override
  Future<void> close() async {}
}

/// Retriever returning a canned context (overrides the real embed→search path).
/// Records the [history] it was last handed so tests can assert prior turns feed
/// back when continuing a conversation.
class FakeRagRetriever extends RagRetriever {
  FakeRagRetriever(super.ref, this._ctx);
  final RagContext _ctx;
  List<RagChatTurn> lastHistory = const [];

  @override
  Future<RagContext> retrieve(
    String question, {
    List<RagChatTurn> history = const [],
    int historyCharBudget = 1500,
    int maxSources = 6,
    int k = 30,
  }) async {
    lastHistory = history;
    return _ctx;
  }
}

RagContext _ctxWithSources(String question) => RagContext(
  question: question,
  sources: const [
    RagSource(index: 1, itemId: 'a', title: 'Live in Tokyo', snippet: 's1'),
    RagSource(index: 2, itemId: 'b', title: 'Studio', snippet: 's2'),
  ],
  systemPrompt: kRagSystemPrompt,
  prompt: 'PROMPT for: $question',
);

RagContext _emptyCtx(String question) => RagContext(
  question: question,
  sources: const [],
  systemPrompt: kRagSystemPrompt,
  prompt: '',
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer makeContainer({
    required RagContext ctx,
    required FakeGenerationEngine engine,
  }) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        ragRetrieverProvider.overrideWith((ref) => FakeRagRetriever(ref, ctx)),
        generationEngineProvider.overrideWithValue(engine),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('send persists the question + streamed, cited answer', () async {
    final engine = FakeGenerationEngine(output: 'It was great [1].');
    final c = makeContainer(
      ctx: _ctxWithSources('what concerts?'),
      engine: engine,
    );

    await c.read(askControllerProvider(null).notifier).send('what concerts?');

    final state = c.read(askControllerProvider(null));
    expect(state.chatId, isNotNull);
    expect(state.busy, isFalse);
    expect(state.streaming, isNull);

    final repo = ChatRepository(db);
    final msgs = await repo.messagesForChat(state.chatId!);
    expect(msgs.map((m) => m.role), [kRoleUser, kRoleAssistant]);
    expect(msgs.first.content, 'what concerts?');
    expect(msgs.last.content, 'It was great [1].');
    expect(decodeCitations(msgs.last.citationsJson).map((x) => x.itemId), [
      'a',
      'b',
    ]);
    expect(engine.prompts.single, 'PROMPT for: what concerts?');
  });

  test('no sources → graceful reply, no generation call', () async {
    final engine = FakeGenerationEngine();
    final c = makeContainer(ctx: _emptyCtx('huh?'), engine: engine);

    await c.read(askControllerProvider(null).notifier).send('huh?');

    final state = c.read(askControllerProvider(null));
    final repo = ChatRepository(db);
    final msgs = await repo.messagesForChat(state.chatId!);
    expect(msgs.map((m) => m.role), [kRoleUser, kRoleAssistant]);
    expect(msgs.last.content, contains("couldn't find anything"));
    expect(msgs.last.citationsJson, isNull);
    expect(engine.prompts, isEmpty); // the LLM was never invoked
  });

  test('a generation failure sets an error and persists no answer', () async {
    final engine = FakeGenerationEngine(fail: true);
    final c = makeContainer(ctx: _ctxWithSources('q'), engine: engine);

    await c.read(askControllerProvider(null).notifier).send('q');

    final state = c.read(askControllerProvider(null));
    expect(state.error, contains("Couldn't answer"));
    expect(state.busy, isFalse);

    final repo = ChatRepository(db);
    final msgs = await repo.messagesForChat(state.chatId!);
    expect(msgs.map((m) => m.role), [kRoleUser]); // user only; no assistant row
  });

  test('continues an existing chat, feeding prior turns as history', () async {
    // Seed a prior, completed turn in an existing conversation.
    final repo = ChatRepository(db);
    final chatId = await repo.createChat('Concerts');
    await repo.appendMessage(chatId, role: kRoleUser, content: 'first?');
    await repo.appendMessage(
      chatId,
      role: kRoleAssistant,
      content: 'first answer',
    );

    final engine = FakeGenerationEngine(output: 'follow-up answer [1].');
    final c = makeContainer(ctx: _ctxWithSources('and then?'), engine: engine);

    // Keyed by the existing id → state is seeded with it (no new chat).
    expect(c.read(askControllerProvider(chatId)).chatId, chatId);

    await c.read(askControllerProvider(chatId).notifier).send('and then?');

    // Same conversation, now four messages (no new chat created).
    final all = await repo.messagesForChat(chatId);
    expect(all.map((m) => m.content), [
      'first?',
      'first answer',
      'and then?',
      'follow-up answer [1].',
    ]);
    expect((await db.select(db.chats).get()).length, 1);

    // The prior turn was fed back as history; the in-flight question is not.
    final retriever = c.read(ragRetrieverProvider) as FakeRagRetriever;
    expect(retriever.lastHistory.map((t) => t.question), ['first?']);
    expect(retriever.lastHistory.map((t) => t.answer), ['first answer']);
  });
}
