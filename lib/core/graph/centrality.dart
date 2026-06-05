/// Pure centrality scoring for the "Rediscover" strip (P13e-2). No Flutter,
/// engine, or AI imports — `GraphQueryService` feeds it the decoded entity
/// memberships + co-download pairs and it returns per-item PageRank, so the
/// whole thing is unit-testable. Sits beside `community_clustering.dart` (the
/// same entity item-graph, scored for importance rather than grouped).
library;

/// A **weighted, undirected** item↔item adjacency built from the entity graph:
/// items sharing an entity bucket ([memberships]; `group` is a type-prefixed key
/// like `u:<id>` / `p:<id>` / `t:<tag>`) gain +1 edge weight per shared bucket,
/// and each direct [pairs] edge (co-download) adds +1 more. Buckets larger than
/// [maxGroupSize] are dropped as **too generic** (the "discard blobs" rule from
/// the clusterer). Returns `id → {neighbor → weight}` (both directions).
Map<String, Map<String, num>> buildItemGraph({
  required List<({String item, String group})> memberships,
  required List<({String a, String b})> pairs,
  int maxGroupSize = 50,
}) {
  final byGroup = <String, List<String>>{};
  for (final m in memberships) {
    (byGroup[m.group] ??= <String>[]).add(m.item);
  }

  final adj = <String, Map<String, num>>{};
  void link(String a, String b) {
    if (a == b) return;
    final ma = adj[a] ??= <String, num>{};
    ma[b] = (ma[b] ?? 0) + 1;
    final mb = adj[b] ??= <String, num>{};
    mb[a] = (mb[a] ?? 0) + 1;
  }

  for (final members in byGroup.values) {
    if (members.length < 2 || members.length > maxGroupSize) continue;
    for (var i = 0; i < members.length; i++) {
      for (var j = i + 1; j < members.length; j++) {
        link(members[i], members[j]);
      }
    }
  }
  for (final p in pairs) {
    link(p.a, p.b);
  }
  return adj;
}

/// Weighted **PageRank** over [adjacency] (from [buildItemGraph]) — each item's
/// score is its standing in the library's web, so hub items (shared with many
/// others through many signals) rank highest. Deterministic power iteration with
/// dangling-mass redistribution; returns `id → score` (scores sum to ~1).
Map<String, double> pageRank(
  Map<String, Map<String, num>> adjacency, {
  int iterations = 40,
  double damping = 0.85,
}) {
  final nodes = adjacency.keys.toList();
  final n = nodes.length;
  if (n == 0) return const {};

  final outWeight = {
    for (final node in nodes)
      node: adjacency[node]!.values.fold<double>(0, (s, w) => s + w),
  };
  final base = (1 - damping) / n;
  var rank = {for (final node in nodes) node: 1.0 / n};

  for (var iter = 0; iter < iterations; iter++) {
    final next = {for (final node in nodes) node: base};
    var danglingMass = 0.0;
    for (final node in nodes) {
      final ow = outWeight[node]!;
      if (ow == 0) {
        danglingMass += rank[node]!;
        continue;
      }
      final share = damping * rank[node]! / ow;
      adjacency[node]!.forEach((nb, w) {
        next[nb] = next[nb]! + share * w;
      });
    }
    if (danglingMass > 0) {
      final spread = damping * danglingMass / n;
      for (final node in nodes) {
        next[node] = next[node]! + spread;
      }
    }
    rank = next;
  }
  return rank;
}
