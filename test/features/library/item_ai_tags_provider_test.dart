import 'package:drift/drift.dart' show Value;
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
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/item_ai_tags_provider.dart';

/// In-memory generation engine that streams a fixed reply.
class FakeGenerationEngine implements GenerationEngine {
  FakeGenerationEngine({
    this.output = 'rock, Live, concert',
    this.fail = false,
  });
  String output;
  bool fail;
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

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed({String? description, List<String> tags = const []}) async {
    await db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: 'a',
            title: 'Live Metal Concert',
            sourceUrl: 'u',
            site: 'youtube',
            filePath: '/m/a',
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
          ),
        );
    await db
        .into(db.mediaMetadata)
        .insert(
          MediaMetadataCompanion.insert(
            itemId: 'a',
            description: Value(description),
          ),
        );
    final repo = MetadataRepository(db);
    for (final t in tags) {
      await repo.addTagToItem('a', t);
    }
  }

  ProviderContainer containerWith(FakeGenerationEngine engine) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        generationEngineProvider.overrideWithValue(engine),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'suggest yields parsed tags, excluding already-applied (P13c)',
    () async {
      await seed(description: 'A blistering set.', tags: ['rock']);
      final engine = FakeGenerationEngine(output: 'rock, Live, concert');
      final c = containerWith(engine);

      await c.read(itemAiTagsProvider('a').notifier).suggest();

      final s = c.read(itemAiTagsProvider('a'));
      expect(s.suggestions, ['live', 'concert']); // 'rock' excluded; lowercased
      expect(s.error, isNull);
      // The title is part of the source the model saw.
      expect(engine.prompts.single, contains('Live Metal Concert'));
    },
  );

  test('remove drops an applied suggestion (P13c)', () async {
    await seed();
    final c = containerWith(FakeGenerationEngine(output: 'live, concert'));
    final n = c.read(itemAiTagsProvider('a').notifier);
    await n.suggest();
    expect(c.read(itemAiTagsProvider('a')).suggestions, ['live', 'concert']);

    n.remove('live');
    expect(c.read(itemAiTagsProvider('a')).suggestions, ['concert']);
  });

  test('a generation failure sets an error (P13c)', () async {
    await seed(description: 'x');
    final c = containerWith(FakeGenerationEngine(fail: true));
    await c.read(itemAiTagsProvider('a').notifier).suggest();
    expect(c.read(itemAiTagsProvider('a')).error, contains("Couldn't suggest"));
  });
}
