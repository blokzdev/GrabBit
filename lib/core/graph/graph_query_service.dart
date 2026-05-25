import 'package:grabbit/core/graph/cooccurrence_ranking.dart';
import 'package:grabbit/core/graph/cozo_query.dart';
import 'package:grabbit/core/graph/graph_store.dart';
import 'package:grabbit/core/graph/related_ranking.dart';

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

  /// Items "like" [id], ranked by a blend of vector similarity (when the item is
  /// embedded) and deterministic graph signals (shared uploader/playlist/tag/
  /// co-download). Works graph-only without embeddings, and returns `[]` when the
  /// store is unavailable. [k] bounds the vector candidate pool; [limit] the
  /// results.
  Future<List<String>> relatedTo(
    String id, {
    int k = 50,
    int limit = 12,
  }) async {
    if (!_store.isAvailable) return const [];

    final vector = await _itemVector(id);
    final vectorHits = vector == null
        ? const <({String id, double distance})>[]
        : [
            for (final hit in await vectorSearch(vector, k: k))
              (id: hit.id, distance: hit.distance),
          ];

    final neighbours = decodeRows(
      await _store.runScript(relatedNeighborsScript(), {'id': id}),
    );
    final signals = <({String id, RelatedSignal signal})>[
      for (final row in neighbours)
        if (row['other'] case final Object other)
          if (RelatedSignal.fromKind('${row['kind']}') case final signal?)
            (id: other.toString(), signal: signal),
    ];

    final exclude = {id, ...await _duplicateIds(id)};
    return blendRelated(
      vectorHits: vectorHits,
      signals: signals,
      exclude: exclude,
      limit: limit,
    );
  }

  /// Tags to **suggest** for item [id]: tags co-occurring with it across the
  /// library (shared uploader/playlist/tag/co-download), ranked by how many
  /// related items carry them, excluding tags it already has. `[]` when the
  /// store is unavailable.
  Future<List<TagCount>> coOccurringTags(String id, {int limit = 8}) async {
    if (!_store.isAvailable) return const [];
    final rows = decodeRows(
      await _store.runScript(coOccurringTagsScript(), {'id': id}),
    );
    return rankCoOccurringTags(_tagPairs(rows), limit: limit);
  }

  /// Tags that co-occur with an entity hub of [type] (`uploader` | `site` |
  /// `playlist` | `tag`) keyed by [value] — the topics common to that entity's
  /// items, ranked by support. A `tag` hub excludes its own tag. `[]` when the
  /// store is unavailable or the type is unknown.
  Future<List<TagCount>> relatedTags(
    String type,
    String value, {
    int limit = 12,
  }) async {
    if (!_store.isAvailable) return const [];
    final script = coOccurringTagsForEntityScript(type);
    if (script == null) return const [];
    final rows = decodeRows(await _store.runScript(script, {'v': value}));
    return rankCoOccurringTags(
      _tagPairs(rows),
      exclude: type == 'tag' ? {value} : const {},
      limit: limit,
    );
  }

  Iterable<({String source, String tag})> _tagPairs(
    List<Map<String, Object?>> rows,
  ) => [
    for (final r in rows)
      if (r['other'] case final Object source)
        if (r['tag'] case final Object tag)
          (source: source.toString(), tag: tag.toString()),
  ];

  Future<List<double>?> _itemVector(String id) async {
    final rows = decodeRows(
      await _store.runScript(itemVectorScript(), {'id': id}),
    );
    if (rows.isEmpty) return null;
    if (rows.first['v'] case final List<Object?> v) {
      return [for (final e in v) (e as num).toDouble()];
    }
    return null;
  }

  Future<Set<String>> _duplicateIds(String id) async {
    final rows = decodeRows(
      await _store.runScript(duplicateIdsScript(), {'id': id}),
    );
    return {
      for (final row in rows)
        if (row['other'] case final Object other) other.toString(),
    };
  }
}
