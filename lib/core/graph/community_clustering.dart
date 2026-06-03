/// Pure community detection for the "Discovered" auto-albums (P13e-1). No
/// Flutter, engine, or AI imports — `GraphQueryService` feeds it the decoded
/// entity memberships + co-download pairs and it returns id communities, so the
/// whole thing is unit-testable. The looser, thematic cousin of the tight
/// similarity clustering in `near_duplicate_clustering.dart`.
library;

/// A detected community: its member ids and the dominant shared **tag** across
/// members (for labeling, when one stands out), if any.
class Community {
  const Community({required this.items, this.dominantTag});

  final List<String> items;
  final String? dominantTag;
}

/// Groups items into communities via **deterministic label propagation** over
/// the entity graph: items sharing an entity bucket ([memberships]; `group` is a
/// type-prefixed key like `u:<id>` / `p:<id>` / `t:<tag>`) are connected, plus
/// the direct [pairs] edges (co-download). Buckets with more than [maxGroupSize]
/// members are dropped as **too generic** (a mega-tag/uploader would merge
/// unrelated items — the "discard blobs" rule from the similarity clusterer).
///
/// Only communities with `minSize ≤ size ≤ maxSize` are returned, largest-first;
/// ids keep first-seen order. Label propagation is sequential (each node adopts
/// the most-frequent neighbour label, ties broken by the lexicographically
/// smallest label) over a fixed node order, so the result is deterministic.
List<Community> detectCommunities({
  required List<({String item, String group})> memberships,
  required List<({String a, String b})> pairs,
  int minSize = 3,
  int maxSize = 30,
  int maxGroupSize = 50,
  int maxIterations = 20,
}) {
  // Stable node order = first appearance (memberships, then pairs).
  final order = <String>[];
  final seen = <String>{};
  void note(String x) {
    if (seen.add(x)) order.add(x);
  }

  final byGroup = <String, List<String>>{};
  for (final m in memberships) {
    note(m.item);
    (byGroup[m.group] ??= <String>[]).add(m.item);
  }
  for (final p in pairs) {
    note(p.a);
    note(p.b);
  }

  // Undirected adjacency among items.
  final adj = <String, Set<String>>{};
  void link(String a, String b) {
    if (a == b) return;
    (adj[a] ??= <String>{}).add(b);
    (adj[b] ??= <String>{}).add(a);
  }

  for (final members in byGroup.values) {
    // Singletons contribute no edge; oversized buckets are too generic.
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

  final nodes = [
    for (final n in order)
      if (adj.containsKey(n)) n,
  ];
  if (nodes.isEmpty) return const [];

  final label = {for (final n in nodes) n: n};
  for (var iter = 0; iter < maxIterations; iter++) {
    var changed = false;
    for (final n in nodes) {
      final counts = <String, int>{};
      for (final nb in adj[n]!) {
        final l = label[nb]!;
        counts[l] = (counts[l] ?? 0) + 1;
      }
      if (counts.isEmpty) continue;
      var best = label[n]!;
      var bestCount = -1;
      counts.forEach((l, c) {
        if (c > bestCount || (c == bestCount && l.compareTo(best) < 0)) {
          best = l;
          bestCount = c;
        }
      });
      if (best != label[n]) {
        label[n] = best;
        changed = true;
      }
    }
    if (!changed) break;
  }

  // Tags carried by each item (for the dominant-tag label seed).
  final tagsByItem = <String, List<String>>{};
  for (final m in memberships) {
    if (m.group.startsWith('t:')) {
      (tagsByItem[m.item] ??= <String>[]).add(m.group.substring(2));
    }
  }

  final byLabel = <String, List<String>>{};
  for (final n in nodes) {
    (byLabel[label[n]!] ??= <String>[]).add(n);
  }

  final communities = <Community>[
    for (final members in byLabel.values)
      if (members.length >= minSize && members.length <= maxSize)
        Community(
          items: members,
          dominantTag: _dominantTag(members, tagsByItem),
        ),
  ]..sort((a, b) => b.items.length.compareTo(a.items.length));
  return communities;
}

/// The tag shared by the most members (support ≥ 2), ties broken by the
/// lexicographically smallest tag; `null` if none stands out.
String? _dominantTag(
  List<String> members,
  Map<String, List<String>> tagsByItem,
) {
  final counts = <String, int>{};
  for (final id in members) {
    for (final t in tagsByItem[id] ?? const <String>[]) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
  }
  String? best;
  var bestCount = 0;
  counts.forEach((t, c) {
    if (c > bestCount ||
        (c == bestCount && best != null && t.compareTo(best!) < 0)) {
      best = t;
      bestCount = c;
    }
  });
  return bestCount >= 2 ? best : null; // support ≥ 2 to be "dominant"
}
