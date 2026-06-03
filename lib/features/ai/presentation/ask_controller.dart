import 'package:grabbit/core/ai/generation_provider.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/features/ai/data/chat_repository.dart';
import 'package:grabbit/features/ai/data/rag_retriever.dart';
import 'package:grabbit/features/ai/presentation/ask_chat.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ask_controller.g.dart';

/// Transient state for the active "Ask your library" conversation (P13d-2a). The
/// persisted transcript is read from `chatMessagesProvider`; this only tracks the
/// in-flight turn — [chatId] (created on the first send), [busy], the [streaming]
/// answer as it generates, and any [error].
class AskState {
  const AskState({this.chatId, this.busy = false, this.streaming, this.error});

  final String? chatId;
  final bool busy;
  final String? streaming;
  final String? error;
}

/// Drives one chat session: each [send] appends the question, re-retrieves fresh
/// RAG sources (reusing d-1) with a bounded slice of prior turns, streams a
/// grounded answer through the local LLM, and persists the turn with its
/// citations. No sources → a graceful "couldn't find" reply, no LLM call. The
/// caller gates on generation readiness (`aiSummaryAction`) before [send].
///
/// Keyed by [chatId] (P13d-2b): a non-null id **continues** that conversation —
/// its persisted history feeds back into the next turn — while `null` starts a
/// fresh chat, created on the first [send] (the d-2a behaviour).
@riverpod
class AskController extends _$AskController {
  @override
  AskState build(String? chatId) => AskState(chatId: chatId);

  Future<void> send(String question) async {
    final q = question.trim();
    if (q.isEmpty || state.busy) return;

    final repo = ref.read(chatRepositoryProvider);
    final chatId = state.chatId ?? await repo.createChat(_deriveTitle(q));
    state = AskState(chatId: chatId, busy: true, streaming: '');
    await repo.appendMessage(chatId, role: kRoleUser, content: q);

    try {
      // The just-appended question is the trailing unanswered message, so
      // `messagesToHistory` drops it; only completed prior turns feed back.
      final history = messagesToHistory(await repo.messagesForChat(chatId));
      final ctx = await ref
          .read(ragRetrieverProvider)
          .retrieve(q, history: history);

      if (!ctx.hasSources) {
        await repo.appendMessage(
          chatId,
          role: kRoleAssistant,
          content: "I couldn't find anything in your library about that.",
        );
        state = AskState(chatId: chatId);
        return;
      }

      final engine = ref.read(generationEngineProvider);
      final buffer = StringBuffer();
      await for (final token in engine.generate(
        ctx.prompt,
        systemPrompt: ctx.systemPrompt,
      )) {
        buffer.write(token);
        state = AskState(
          chatId: chatId,
          busy: true,
          streaming: buffer.toString(),
        );
      }
      final answer = buffer.toString().trim();
      if (answer.isNotEmpty) {
        await repo.appendMessage(
          chatId,
          role: kRoleAssistant,
          content: answer,
          citationsJson: encodeCitations(ctx.sources),
        );
      }
      state = AskState(chatId: chatId);
    } on InferenceException catch (e) {
      state = AskState(chatId: chatId, error: "Couldn't answer — ${e.message}");
    }
  }

  /// A compact, single-line chat title from the first question.
  String _deriveTitle(String q) {
    final oneLine = q.replaceAll(RegExp(r'\s+'), ' ').trim();
    return oneLine.length <= 60
        ? oneLine
        : '${oneLine.substring(0, 60).trimRight()}…';
  }
}
