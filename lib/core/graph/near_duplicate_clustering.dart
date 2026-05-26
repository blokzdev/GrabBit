/// Pure similarity clustering for "Suggested albums" (P10c-d-2). No Flutter,
/// engine, or AI imports — `GraphQueryService` feeds it the decoded embeddings
/// and it returns id clusters, so the whole thing is unit-testable.
library;

import 'dart:math' as math;

/// Default cosine-distance ceiling for two items to count as "similar". Tight by
/// design (high precision) — looser thematic grouping is P13's community
/// detection. Tunable; the vector values themselves are only exercised on the
/// arm64 native engine, so this is validated on-device.
const double kSimilarityMaxDistance = 0.2;

/// Cosine distance (`1 - cosineSimilarity`) between two equal-length vectors.
/// Returns `1.0` (maximally distant) for a zero-magnitude vector rather than
/// dividing by zero.
double cosineDistance(List<double> a, List<double> b) {
  var dot = 0.0;
  var na = 0.0;
  var nb = 0.0;
  final n = math.min(a.length, b.length);
  for (var i = 0; i < n; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na == 0 || nb == 0) return 1.0;
  final sim = dot / (math.sqrt(na) * math.sqrt(nb));
  return (1.0 - sim).clamp(0.0, 2.0);
}

/// An unordered pair key (`min|max`) for excluding known pairs.
String pairKey(String a, String b) => a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

/// Groups [items] into similarity clusters: items within [maxDistance] (cosine)
/// of each other are edges, and connected components become clusters. Pairs in
/// [excludePairs] (e.g. exact duplicates) are not edges. Only components with
/// `minSize ≤ size ≤ maxSize` are returned — singletons/pairs are dropped and
/// over-large "blob" components are discarded (that's P13's job). Clusters are
/// ordered largest-first; ids within a cluster keep their input order.
List<List<String>> clusterBySimilarity(
  List<({String id, List<double> v})> items, {
  double maxDistance = kSimilarityMaxDistance,
  int minSize = 3,
  int maxSize = 30,
  Set<String> excludePairs = const {},
}) {
  final n = items.length;
  if (n < minSize) return const [];

  // Union-find over item indices.
  final parent = List<int>.generate(n, (i) => i);
  int find(int x) {
    var r = x;
    while (parent[r] != r) {
      r = parent[r];
    }
    while (parent[x] != r) {
      final next = parent[x];
      parent[x] = r;
      x = next;
    }
    return r;
  }

  void union(int a, int b) => parent[find(a)] = find(b);

  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      if (excludePairs.contains(pairKey(items[i].id, items[j].id))) continue;
      if (cosineDistance(items[i].v, items[j].v) <= maxDistance) union(i, j);
    }
  }

  final byRoot = <int, List<String>>{};
  for (var i = 0; i < n; i++) {
    (byRoot[find(i)] ??= <String>[]).add(items[i].id);
  }

  final clusters = [
    for (final members in byRoot.values)
      if (members.length >= minSize && members.length <= maxSize) members,
  ]..sort((a, b) => b.length.compareTo(a.length));
  return clusters;
}
