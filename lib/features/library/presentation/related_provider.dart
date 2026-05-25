import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/graph/graph_query_provider.dart';

// Manual provider (not riverpod_generator): returns Drift's generated `MediaItem`
// row type, which the generator can't resolve (InvalidTypeException).

/// "More like this" for an item: graph-query the related ids (vector + graph
/// signals), then hydrate them to [MediaItem]s preserving rank order. Returns
/// `[]` when the graph is unavailable or nothing is related — the detail screen
/// then simply shows no section.
final relatedItemsProvider = FutureProvider.family<List<MediaItem>, String>((
  ref,
  itemId,
) async {
  final ids = await ref.watch(graphQueryServiceProvider).relatedTo(itemId);
  if (ids.isEmpty) return const [];

  final db = ref.watch(appDatabaseProvider);
  final found = await (db.select(
    db.mediaItems,
  )..where((t) => t.id.isIn(ids))).get();
  final byId = {for (final m in found) m.id: m};
  return [
    for (final id in ids)
      if (byId[id] case final MediaItem item) item,
  ];
});
