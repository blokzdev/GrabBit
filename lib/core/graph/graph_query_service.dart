import 'package:grabbit/core/graph/centrality.dart';
import 'package:grabbit/core/graph/community_clustering.dart';
import 'package:grabbit/core/graph/cooccurrence_ranking.dart';
import 'package:grabbit/core/graph/cozo_query.dart';
import 'package:grabbit/core/graph/graph_store.dart';
import 'package:grabbit/core/graph/near_duplicate_clustering.dart';
import 'package:grabbit/core/graph/related_ranking.dart';

/// One nearest-neighbour hit from a vector search: a media item id and its
/// cosine distance (smaller = closer).
class VectorHit {
  const VectorHit(this.id, this.distance);

  final String id;
  final double distance;
}

/// One node connected to a media item in the graph neighborhood (P10c-e):
/// [relation] ∈ `uploader|playlist|site|tag|duplicate|codownload`, [id] the
/// target's key, [label] its display name.
class GraphNeighbor {
  const GraphNeighbor({
    required this.relation,
    required this.id,
    required this.label,
  });

  final String relation;
  final String id;
  final String label;
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

  /// Similarity clusters across the whole library for **Suggested albums**
  /// (P10c-d-2): pull every stored vector + the exact-duplicate pairs, then group
  /// by pairwise cosine in Dart (connected components, exact pairs excluded).
  /// `[]` when the store is unavailable. Heavy lifting is pure + testable; only
  /// two simple reads hit the engine.
  Future<List<List<String>>> similarityClusters({
    double maxDistance = kSimilarityMaxDistance,
    int minSize = 3,
  }) async {
    if (!_store.isAvailable) return const [];
    final embeddings = [
      for (final r in decodeRows(await _store.runScript(allEmbeddingsScript())))
        if (r['id'] case final Object id)
          if (r['v'] case final List<Object?> v)
            (id: id.toString(), v: [for (final e in v) (e as num).toDouble()]),
    ];
    if (embeddings.length < minSize) return const [];
    final exclude = <String>{
      for (final r in decodeRows(
        await _store.runScript(allDuplicatePairsScript()),
      ))
        if (r['a'] case final Object a)
          if (r['b'] case final Object b) pairKey(a.toString(), b.toString()),
    };
    return clusterBySimilarity(
      embeddings,
      maxDistance: maxDistance,
      minSize: minSize,
      excludePairs: exclude,
    );
  }

  /// Thematic **communities** over the entity graph (P13e-1) — items linked
  /// through a web of shared uploader/playlist/tag signals + co-download edges,
  /// grouped by deterministic label propagation. Every-device (pure Datalog +
  /// Dart; no embedder, unlike [similarityClusters]). `[]` when unavailable.
  Future<List<Community>> communityClusters({
    int minSize = 3,
    int maxSize = 30,
    int maxGroupSize = 50,
  }) async {
    if (!_store.isAvailable) return const [];
    final (:memberships, :pairs) = await _entityGraph();
    if (memberships.isEmpty) return const [];
    return detectCommunities(
      memberships: memberships,
      pairs: pairs,
      minSize: minSize,
      maxSize: maxSize,
      maxGroupSize: maxGroupSize,
    );
  }

  /// PageRank **centrality** of every connected item over the entity graph
  /// (P13e-2) — `id → score`, ranking items by how woven they are into the
  /// library's web (shared uploader/playlist/tag + co-download). Every-device
  /// (pure Datalog + Dart; no embedder). `{}` when the store is unavailable.
  /// Feeds the "Rediscover" strip via `rankRediscover`.
  Future<Map<String, double>> itemCentrality({int maxGroupSize = 50}) async {
    if (!_store.isAvailable) return const {};
    final (:memberships, :pairs) = await _entityGraph();
    if (memberships.isEmpty && pairs.isEmpty) return const {};
    return pageRank(
      buildItemGraph(
        memberships: memberships,
        pairs: pairs,
        maxGroupSize: maxGroupSize,
      ),
    );
  }

  /// Decodes the entity-membership (`item`, type-prefixed `group`) + co-download
  /// (`a`/`b`) pulls shared by the community (P13e-1) and centrality (P13e-2)
  /// builders over the deterministic entity graph.
  Future<
    ({
      List<({String item, String group})> memberships,
      List<({String a, String b})> pairs,
    })
  >
  _entityGraph() async {
    final memberships = [
      for (final r in decodeRows(
        await _store.runScript(entityMembershipScript()),
      ))
        if (r['mediaId'] case final Object id)
          if (r['kind'] case final Object kind)
            if (r['key'] case final Object key)
              (item: id.toString(), group: '$kind:$key'),
    ];
    final pairs = [
      for (final r in decodeRows(
        await _store.runScript(coDownloadPairsScript()),
      ))
        if (r['a'] case final Object a)
          if (r['b'] case final Object b) (a: a.toString(), b: b.toString()),
    ];
    return (memberships: memberships, pairs: pairs);
  }

  /// The immediate graph neighborhood of media item [id] — its connected
  /// entities + directly-linked media — for the graph-view render (P10c-e).
  /// `[]` when the store is unavailable. Pure deterministic edges; no embedder.
  Future<List<GraphNeighbor>> neighborhood(String id) async {
    if (!_store.isAvailable) return const [];
    final rows = decodeRows(
      await _store.runScript(neighborhoodScript(), {'id': id}),
    );
    return [
      for (final r in rows)
        if (r['rel'] case final Object rel)
          if (r['id'] case final Object nid)
            if (r['label'] case final Object label)
              GraphNeighbor(
                relation: rel.toString(),
                id: nid.toString(),
                label: label.toString(),
              ),
    ];
  }

  /// Media belonging to an entity (`relation` ∈ `uploader|playlist|site|tag`,
  /// keyed by [value]) — for expanding an entity node in the graph view
  /// (P10c-f), returned as `item` [GraphNeighbor]s (which navigate to the item).
  /// `[]` when the store is unavailable or the relation isn't an entity.
  Future<List<GraphNeighbor>> entityMedia(
    String relation,
    String value, {
    int limit = 30,
  }) async {
    if (!_store.isAvailable) return const [];
    final script = mediaForEntityScript(relation, limit: limit);
    if (script == null) return const [];
    final rows = decodeRows(await _store.runScript(script, {'v': value}));
    return [
      for (final r in rows)
        if (r['id'] case final Object id)
          if (r['title'] case final Object title)
            GraphNeighbor(
              relation: 'item',
              id: id.toString(),
              label: title.toString(),
            ),
    ];
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
