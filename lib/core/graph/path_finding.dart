/// Pure shortest-connection ("how are these related?") path finding for P13e-3a.
/// No Flutter, engine, or AI imports — `GraphQueryService` feeds it the decoded
/// entity memberships + co-download pairs and it returns the connection between
/// two items, so the whole thing is unit-testable. Sits beside
/// `community_clustering.dart` / `centrality.dart` (the same entity graph,
/// traversed for a path rather than grouped or scored).
library;

import 'dart:collection';

/// The shortest connection between two media items: the ordered item ids
/// (`source`..`target`, length ≥ 2) and the human [connectors] describing each
/// hop between consecutive items (`connectors.length == itemIds.length - 1`).
class GraphPath {
  const GraphPath({required this.itemIds, required this.connectors});

  final List<String> itemIds;
  final List<String> connectors;
}

/// Finds the shortest connection [source]→[target] over the **bipartite**
/// item↔entity graph: item nodes + entity-bucket nodes (`group` = `u:<id>` /
/// `p:<id>` / `t:<tag>` from `GraphQueryService._entityGraph()`), with an
/// edge for each membership (item—bucket) plus each direct co-download [pairs]
/// edge (item—item). Over-generic buckets (> [maxGroupSize] members) are
/// **skipped** so a mega-tag can't fabricate a spurious 2-hop link (the e-1/e-2
/// "discard blobs" rule).
///
/// BFS → fewest hops; **deterministic** (sorted adjacency + FIFO discovery, ties
/// → lexicographically smallest key). Each entity hop **collapses** into a
/// connector between the two items it bridges (`u` → "same channel", `p` → "same
/// playlist", `t` → "shared tag"); a direct co-download edge → "downloaded
/// together". Returns `null` when `source == target` or the two are disconnected.
GraphPath? findItemPath({
  required String source,
  required String target,
  required List<({String item, String group})> memberships,
  required List<({String a, String b})> pairs,
  int maxGroupSize = 50,
}) {
  if (source == target) return null;

  final groupMembers = <String, Set<String>>{};
  for (final m in memberships) {
    (groupMembers[m.group] ??= <String>{}).add(m.item);
  }

  final adj = <String, Set<String>>{};
  void link(String a, String b) {
    if (a == b) return;
    (adj[a] ??= <String>{}).add(b);
    (adj[b] ??= <String>{}).add(a);
  }

  groupMembers.forEach((group, members) {
    // A singleton bucket connects nothing; an over-generic one connects too much.
    if (members.length < 2 || members.length > maxGroupSize) return;
    final gNode = 'g:$group';
    for (final item in members) {
      link('i:$item', gNode);
    }
  });
  for (final p in pairs) {
    link('i:${p.a}', 'i:${p.b}');
  }

  final src = 'i:$source';
  final dst = 'i:$target';
  if (!adj.containsKey(src) || !adj.containsKey(dst)) return null;

  final parent = <String, String>{src: src};
  final queue = Queue<String>()..add(src);
  while (queue.isNotEmpty) {
    final node = queue.removeFirst();
    if (node == dst) break;
    for (final nb in adj[node]!.toList()..sort()) {
      if (!parent.containsKey(nb)) {
        parent[nb] = node;
        queue.add(nb);
      }
    }
  }
  if (!parent.containsKey(dst)) return null;

  final reversed = <String>[];
  for (var cur = dst; cur != src; cur = parent[cur]!) {
    reversed.add(cur);
  }
  reversed.add(src);
  final nodes = reversed.reversed.toList();

  // Collapse the alternating item/entity node path into items + connectors.
  final itemIds = <String>[nodes.first.substring(2)];
  final connectors = <String>[];
  String? pendingGroup;
  for (final node in nodes.skip(1)) {
    if (node.startsWith('g:')) {
      pendingGroup = node.substring(2);
      continue;
    }
    connectors.add(
      pendingGroup != null
          ? _connectorFor(pendingGroup)
          : 'downloaded together',
    );
    pendingGroup = null;
    itemIds.add(node.substring(2));
  }
  return GraphPath(itemIds: itemIds, connectors: connectors);
}

/// Human connector for an entity bucket `"<kind>:<key>"`.
String _connectorFor(String group) {
  final sep = group.indexOf(':');
  final kind = group.substring(0, sep);
  final key = group.substring(sep + 1);
  return switch (kind) {
    'u' => 'same channel',
    'p' => 'same playlist',
    't' => "shared tag '$key'",
    _ => 'related',
  };
}
