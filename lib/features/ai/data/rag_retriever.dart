import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/ai/embedder_engine_provider.dart';
import 'package:grabbit/core/graph/graph_query_provider.dart';
import 'package:grabbit/features/ai/data/rag_context.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/semantic_search_provider.dart';

/// Retrieves the most relevant library items for a question and assembles the
/// grounding context + prompt for the local LLM (P13d-1) — the engine the Ask
/// chat (d-2) drives. Reuses the existing semantic-search substrate (embed →
/// vector search) + a light graph expansion; degrades to an empty-sources
/// context when retrieval isn't available (no embedder / empty index) so the
/// caller can fall back gracefully. No generation here — that's d-2.
class RagRetriever {
  RagRetriever(this._ref);

  final Ref _ref;

  /// Retrieves sources for [question] and builds the prompt. [history] (prior
  /// turns) is folded in, bounded by [historyCharBudget] (the tier knob).
  Future<RagContext> retrieve(
    String question, {
    List<RagChatTurn> history = const [],
    int historyCharBudget = 1500,
    int maxSources = 6,
    int k = 30,
  }) async {
    final q = question.trim();
    final empty = RagContext(
      question: q,
      sources: const [],
      systemPrompt: kRagSystemPrompt,
      prompt: '',
    );
    if (q.isEmpty) return empty;
    // Retrieval needs the query embedder ready; the vector search itself returns
    // [] when the graph/index is unavailable.
    if (!await _ref.read(semanticSearchReadyProvider.future)) return empty;

    final vector = await _ref.read(embedderEngineProvider).embed(q);
    final query = _ref.read(graphQueryServiceProvider);
    final hits = await query.vectorSearch(vector, k: k);
    if (hits.isEmpty) return empty;

    // Light graph re-rank: add a few items connected to the top hit so context
    // isn't purely vector-nearest (bounded; cheap on modest libraries).
    final related = await query.relatedTo(hits.first.id, limit: 4);
    final ids = selectRagSources([
      for (final h in hits) h.id,
      ...related,
    ], max: maxSources);

    final repo = _ref.read(metadataRepositoryProvider);
    final sources = <RagSource>[];
    for (final id in ids) {
      final item = await repo.mediaItemById(id);
      if (item == null) continue;
      final meta = await repo.metadataForItem(id);
      final tags = await repo.tagNamesForItem(id);
      sources.add(
        RagSource(
          index: sources.length + 1,
          itemId: id,
          title: item.title,
          snippet: buildSourceSnippet(
            uploader: meta?.uploader,
            tags: tags,
            description: meta?.description,
            transcript: meta?.transcript,
            aiSummary: meta?.aiSummary,
            ocrText: meta?.ocrText,
          ),
        ),
      );
    }
    if (sources.isEmpty) return empty;
    return RagContext(
      question: q,
      sources: sources,
      systemPrompt: kRagSystemPrompt,
      prompt: buildRagPrompt(
        q,
        sources,
        history: history,
        historyCharBudget: historyCharBudget,
      ),
    );
  }
}

final ragRetrieverProvider = Provider<RagRetriever>(RagRetriever.new);
