import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/ai/inference_engine_provider.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/graph/embedding_doc.dart';
import 'package:grabbit/core/graph/graph_query_provider.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

// Manual providers (not riverpod_generator): `semanticResultsProvider` returns
// Drift's generated `MediaItem` row type, which the generator can't resolve
// (InvalidTypeException) — so the whole file stays hand-written for consistency.

/// Whether semantic search is usable right now: the user has opted in
/// ([SettingsModel.semanticSearchEnabled]) **and** the embedder is loaded and
/// ready. Drives whether the library offers the Smart-search toggle at all.
final semanticSearchReadyProvider = FutureProvider<bool>((ref) async {
  final settings = await ref.watch(settingsControllerProvider.future);
  if (!settings.semanticSearchEnabled) return false;
  return ref.watch(inferenceEngineProvider).ensureReady();
});

/// Library items most semantically similar to [query], ranked nearest-first.
/// Embeds the query string, runs an HNSW vector search over the Cozo index, then
/// hydrates the hit ids back to [MediaItem]s (preserving rank order). Returns
/// `[]` for an empty query or when semantic search isn't ready.
final semanticResultsProvider = FutureProvider.family<List<MediaItem>, String>((
  ref,
  query,
) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const [];
  if (!await ref.watch(semanticSearchReadyProvider.future)) return const [];

  // EmbeddingGemma needs the search-query prompt to match the document space.
  final vector = await ref
      .watch(inferenceEngineProvider)
      .embed(embeddingQueryPrompt(trimmed));
  final hits = await ref.watch(graphQueryServiceProvider).vectorSearch(vector);
  if (hits.isEmpty) return const [];

  final db = ref.watch(appDatabaseProvider);
  final ids = [for (final h in hits) h.id];
  final found = await (db.select(
    db.mediaItems,
  )..where((t) => t.id.isIn(ids))).get();
  final byId = {for (final m in found) m.id: m};
  return [
    for (final h in hits)
      if (byId[h.id] case final MediaItem item) item,
  ];
});
