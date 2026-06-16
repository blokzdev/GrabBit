import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/ai/embedder_engine_provider.dart';
import 'package:grabbit/core/graph/graph_query_provider.dart';
import 'package:grabbit/core/graph/graph_query_service.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/core/things/thing_hydration.dart';
import 'package:grabbit/core/things/thing_repository.dart';
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
    // Recall over the media `embedding` and the P16f `thing_embedding` indexes,
    // merged nearest-first — so a non-media Thing (Recipe/Article/…) is recalled.
    final hits = [
      ...await query.vectorSearch(vector, k: k),
      ...await _thingHits(query, vector, k),
    ]..sort((a, b) => a.distance.compareTo(b.distance));
    if (hits.isEmpty) return empty;

    // Light graph re-rank: add a few items connected to the top hit so context
    // isn't purely vector-nearest (bounded; cheap on modest libraries).
    final related = await query.relatedTo(hits.first.id, limit: 4);
    final ids = selectRagSources([
      for (final h in hits) h.id,
      ...related,
    ], max: maxSources);

    // Resolve hits through the Thing-aware seam so answers cite Things
    // (MediaObject today); the rich snippet still comes from the metadata row
    // keyed by the same id (thing.id == media_items.id for MediaObjects).
    final nodes = await _ref.read(nodeHydrationProvider).hydrateNodes(ids);
    final repo = _ref.read(metadataRepositoryProvider);
    final things = _ref.read(thingRepositoryProvider);
    final sources = <RagSource>[];
    for (final node in nodes) {
      // A media-backed node cites its rich metadata snippet; a non-media Thing
      // (P16f) cites a snippet built from its own JSON-LD properties.
      final String snippet;
      if (node.media != null) {
        final meta = await repo.metadataForItem(node.id);
        final tags = await repo.tagNamesForItem(node.id);
        snippet = buildSourceSnippet(
          uploader: meta?.uploader,
          tags: tags,
          description: meta?.description,
          transcript: meta?.transcript,
          aiSummary: meta?.aiSummary,
          ocrText: meta?.ocrText,
        );
      } else {
        snippet = await _thingSnippet(things, node.id);
      }
      sources.add(
        RagSource(
          index: sources.length + 1,
          itemId: node.id,
          title: node.title,
          type: node.type,
          snippet: snippet,
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

  /// Vector hits over the `thing_embedding` index, resilient to it not existing
  /// yet (no Things embedded / a pre-P16f index) — returns `[]` rather than throw.
  Future<List<VectorHit>> _thingHits(
    GraphQueryService query,
    List<double> vector,
    int k,
  ) async {
    try {
      return await query.vectorSearch(
        vector,
        k: k,
        relation: 'thing_embedding',
      );
    } catch (_) {
      return const [];
    }
  }

  /// The grounding snippet for a non-media Thing, from its JSON-LD; '' when the
  /// Thing is gone or unparseable.
  Future<String> _thingSnippet(ThingRepository things, String id) async {
    final thing = await things.thingById(id);
    if (thing == null) return '';
    try {
      return buildThingSnippet(ThingDoc.fromJsonString(thing.jsonld));
    } on FormatException {
      return '';
    }
  }
}

final ragRetrieverProvider = Provider<RagRetriever>(RagRetriever.new);
