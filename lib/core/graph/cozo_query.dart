/// Pure CozoScript **read** builders + a result decoder. Kept free of Flutter and
/// the native bridge so the query shapes are unit-testable the same way
/// `cozo_schema.dart` keeps the write side testable. `GraphQueryService` runs
/// these against the `GraphStore`; the UI never touches CozoScript.
library;

/// HNSW nearest-neighbour search over the `embedding:idx` vector index
/// (cosine; built in P10b-2b). Binds `$q` (the query vector as a JSON array,
/// coerced with `vec`), `$k` (neighbours) and `$ef` (search breadth), returning
/// `[id, dist]` ordered nearest-first.
///
/// NOTE: the exact `~embedding:idx{…}` syntax is only exercisable on the arm64
/// native engine (`cozo_android`), so it is confirmed on-device — this builder is
/// the single place to adjust if the dialect differs.
String vectorSearchScript() =>
    '?[id, dist] := ~embedding:idx{ id | query: vec(\$q), k: \$k, ef: \$ef, '
    'bind_distance: dist }\n'
    ':order dist\n'
    ':limit \$k';

/// Reads the stored embedding vector for `$id` (`[v]`, empty if the item hasn't
/// been embedded yet). Lets "more like this" search by an item's *own* vector
/// without re-embedding — so the read side never touches the AI layer.
String itemVectorScript() => '?[v] := *embedding{id: \$id, v}';

/// Graph neighbours that share a deterministic signal with `$id`, as
/// `[other, kind, val]` rows (one row per shared connection). `kind` ∈
/// `uploader | playlist | tag | codownload`; `val` is the shared key (uploader
/// id / playlist id / tag), or `''` for co-download. Emitting one row per shared
/// **tag** (rather than collapsing) lets the ranker weight by overlap count.
/// Pure Datalog — no vector syntax — so it runs and is reasoned about without
/// the native HNSW index.
String relatedNeighborsScript() =>
    '?[other, kind, val] := *postedBy{mediaId: \$id, uploaderId: u}, '
    '*postedBy{mediaId: other, uploaderId: u}, other != \$id, '
    'kind = "uploader", val = u\n'
    '?[other, kind, val] := *inPlaylist{mediaId: \$id, playlistId: p}, '
    '*inPlaylist{mediaId: other, playlistId: p}, other != \$id, '
    'kind = "playlist", val = p\n'
    '?[other, kind, val] := *taggedWith{mediaId: \$id, tag: t}, '
    '*taggedWith{mediaId: other, tag: t}, other != \$id, kind = "tag", val = t\n'
    '?[other, kind, val] := *coDownloadedWith{mediaId: \$id, otherId: other}, '
    'kind = "codownload", val = ""\n'
    '?[other, kind, val] := *coDownloadedWith{mediaId: other, otherId: \$id}, '
    'kind = "codownload", val = ""';

/// Ids that are exact duplicates of `$id` (`duplicateOf` either direction).
/// "More like this" excludes these — a duplicate is the *same* item, not a
/// similar one; near-duplicate clustering is its own feature (P10c-d).
String duplicateIdsScript() =>
    '?[other] := *duplicateOf{mediaId: \$id, otherId: other}\n'
    '?[other] := *duplicateOf{mediaId: other, otherId: \$id}';

/// Every stored embedding as `[id, v]` (the vector is a list of doubles). Drives
/// the global similarity-clustering pass (P10c-d-2) — pairwise cosine is computed
/// in Dart, so this is the only vector read needed for clustering.
String allEmbeddingsScript() => '?[id, v] := *embedding{id, v}';

/// Every exact-duplicate pair as `[a, b]` (one direction per stored row). Used to
/// exclude byte-identical pairs from similarity clusters so "Suggested" albums
/// read as *similar*, not the same file (those live in the Duplicates album).
String allDuplicatePairsScript() =>
    '?[a, b] := *duplicateOf{mediaId: a, otherId: b}';

/// Tags co-occurring with item `$id`: tags on the items that share a
/// deterministic signal with it (same uploader/playlist/tag/co-download),
/// excluding the tags `$id` already carries. Emits one `[other, tag]` row per
/// related-item/tag pair so the Dart ranker (`rankCoOccurringTags`) can count
/// distinct supporting items per tag. Powers tag **suggestions** (P10c-c-2).
/// Pure Datalog (named rules + stratified negation) — no vector syntax.
String coOccurringTagsScript() =>
    'related[other] := *postedBy{mediaId: \$id, uploaderId: u}, '
    '*postedBy{mediaId: other, uploaderId: u}, other != \$id\n'
    'related[other] := *inPlaylist{mediaId: \$id, playlistId: p}, '
    '*inPlaylist{mediaId: other, playlistId: p}, other != \$id\n'
    'related[other] := *taggedWith{mediaId: \$id, tag: t}, '
    '*taggedWith{mediaId: other, tag: t}, other != \$id\n'
    'related[other] := *coDownloadedWith{mediaId: \$id, otherId: other}\n'
    'related[other] := *coDownloadedWith{mediaId: other, otherId: \$id}\n'
    'own[t] := *taggedWith{mediaId: \$id, tag: t}\n'
    '?[other, tag] := related[other], *taggedWith{mediaId: other, tag}, '
    'not own[tag]';

/// Tags co-occurring with an entity **hub** of [type] (`uploader` | `site` |
/// `playlist` | `tag`), bound by `$v`: the tags carried by the items that belong
/// to that entity. Emits `[other, tag]` rows (one per member-item/tag) for the
/// Dart ranker; `null` for an unknown type (the service then returns nothing).
/// Uploader hubs key by *name* (matching the library facet), bridged to the
/// graph's `uploaderId` via the `uploader` node. Powers the hub's related-tags
/// strip (P10c-c-2).
String? coOccurringTagsForEntityScript(String type) {
  final member = switch (type) {
    'tag' => 'member[other] := *taggedWith{mediaId: other, tag: \$v}',
    'site' => 'member[other] := *onPlatform{mediaId: other, site: \$v}',
    'playlist' =>
      'member[other] := *inPlaylist{mediaId: other, playlistId: \$v}',
    'uploader' =>
      'member[other] := *uploader{uploaderId: uid, name: \$v}, '
          '*postedBy{mediaId: other, uploaderId: uid}',
    _ => null,
  };
  if (member == null) return null;
  return '$member\n'
      '?[other, tag] := member[other], *taggedWith{mediaId: other, tag}';
}

/// The immediate graph neighborhood of media item `$id` as `[rel, id, label]`
/// rows — its connected entities (uploader/playlist/site/tag) and directly
/// linked media (duplicate/co-download). `rel` ∈ `uploader|playlist|site|tag|
/// duplicate|codownload`; `id` is the target's key (uploaderId/playlistId/site/
/// tag-name/other-media-id); `label` is its display name. Pure Datalog over the
/// deterministic edges — renders on any graph device without the embedder
/// (P10c-e). Entity hubs/media nodes are labelled by joining their node relation.
String neighborhoodScript() =>
    '?[rel, id, label] := *postedBy{mediaId: \$id, uploaderId: u}, '
    '*uploader{uploaderId: u, name: label}, rel = "uploader", id = u\n'
    '?[rel, id, label] := *inPlaylist{mediaId: \$id, playlistId: p}, '
    '*playlist{playlistId: p, title: label}, rel = "playlist", id = p\n'
    '?[rel, id, label] := *onPlatform{mediaId: \$id, site: s}, '
    'rel = "site", id = s, label = s\n'
    '?[rel, id, label] := *taggedWith{mediaId: \$id, tag: t}, '
    'rel = "tag", id = t, label = t\n'
    '?[rel, id, label] := *duplicateOf{mediaId: \$id, otherId: o}, '
    '*media{id: o, title: label}, rel = "duplicate", id = o\n'
    '?[rel, id, label] := *coDownloadedWith{mediaId: \$id, otherId: o}, '
    '*media{id: o, title: label}, rel = "codownload", id = o';

/// Media belonging to an entity, for expanding an entity node in the graph view
/// (P10c-f). `relation` ∈ `uploader|playlist|site|tag` selects the edge; `$v` is
/// the entity key. Returns up to [limit] `[id, title]` rows; `null` for a
/// relation that isn't an expandable entity (media nodes navigate instead).
String? mediaForEntityScript(String relation, {int limit = 30}) {
  final match = switch (relation) {
    'uploader' => '*postedBy{mediaId: id, uploaderId: \$v}',
    'site' => '*onPlatform{mediaId: id, site: \$v}',
    'tag' => '*taggedWith{mediaId: id, tag: \$v}',
    'playlist' => '*inPlaylist{mediaId: id, playlistId: \$v}',
    _ => null,
  };
  if (match == null) return null;
  return '?[id, title] := $match, *media{id, title}\n:limit $limit';
}

/// Decodes a CozoScript result (`{headers: [...], rows: [[...], ...]}`) into a
/// list of column-keyed maps. Tolerant of a missing/empty `headers` or `rows`
/// (returns `const []`). Generalises the `graphRelationNames` header-scan in
/// `android_cozo_graph_store.dart` for reuse across every P10c query.
List<Map<String, Object?>> decodeRows(Map<String, Object?> result) {
  final headers = (result['headers'] as List?)?.cast<Object?>() ?? const [];
  final rows = (result['rows'] as List?)?.cast<Object?>() ?? const [];
  if (headers.isEmpty || rows.isEmpty) return const [];
  final names = [for (final h in headers) h.toString()];
  return [
    for (final row in rows)
      if (row is List)
        {
          for (var i = 0; i < names.length && i < row.length; i++)
            names[i]: row[i],
        },
  ];
}
