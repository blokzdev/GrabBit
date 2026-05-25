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
