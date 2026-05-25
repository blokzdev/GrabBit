import 'package:grabbit/core/graph/cozo_query.dart';
import 'package:grabbit/core/graph/graph_store.dart';

/// One nearest-neighbour hit from a vector search: a media item id and its
/// cosine distance (smaller = closer).
class VectorHit {
  const VectorHit(this.id, this.distance);

  final String id;
  final double distance;
}

/// Read-side orchestration over the [GraphStore], mirroring how
/// `GraphSyncService` owns write/sync orchestration — the store stays a thin
/// `runScript` bridge. Every query degrades gracefully: when the store isn't
/// available (unsupported ABI, not yet opened) it returns empty results rather
/// than throwing, so callers can simply offer nothing.
class GraphQueryService {
  GraphQueryService(this._store);

  final GraphStore _store;

  /// Nearest library items to [query] (a `dimension`-length embedding), ordered
  /// nearest-first. Returns `[]` when the store is unavailable or the index is
  /// empty.
  Future<List<VectorHit>> vectorSearch(
    List<double> query, {
    int k = 50,
    int ef = 100,
  }) async {
    if (!_store.isAvailable) return const [];
    final result = await _store.runScript(vectorSearchScript(), {
      'q': query,
      'k': k,
      'ef': ef,
    });
    return [
      for (final row in decodeRows(result))
        if (row['id'] case final Object id)
          VectorHit(id.toString(), (row['dist'] as num?)?.toDouble() ?? 0),
    ];
  }
}
