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
