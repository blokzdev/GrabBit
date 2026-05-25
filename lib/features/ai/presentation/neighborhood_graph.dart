import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:grabbit/core/graph/graph_query_service.dart';

/// Builds the `graphview` [Graph] for a media item's neighborhood and the
/// per-relation styling shared by the renderer + legend (P10c-e). Kept free of
/// Riverpod/I/O so graph construction is unit-testable without rendering.

/// Node key for the centre media item (distinct from any neighbor key).
const String kCenterKey = '__center__';

/// Stable, unique node key for a neighbor (`'<relation>::<id>'`) — prevents
/// collisions between, say, a tag named like a media id.
String neighborKey(GraphNeighbor n) => '${n.relation}::${n.id}';

/// Relations rendered around the centre, in legend order.
const List<String> kNeighborRelations = [
  'uploader',
  'playlist',
  'site',
  'tag',
  'duplicate',
  'codownload',
];

/// Human label for a relation (legend + a11y).
String relationLabel(String relation) => switch (relation) {
  'uploader' => 'Channel',
  'playlist' => 'Playlist',
  'site' => 'Platform',
  'tag' => 'Tag',
  'duplicate' => 'Duplicate',
  'codownload' => 'Co-downloaded',
  'item' => 'Item',
  _ => relation,
};

/// Icon for a relation's node/legend chip.
IconData relationIcon(String relation) => switch (relation) {
  'uploader' => Icons.person_outline,
  'playlist' => Icons.playlist_play,
  'site' => Icons.public,
  'tag' => Icons.label_outline,
  'duplicate' => Icons.content_copy_outlined,
  'codownload' => Icons.schedule_outlined,
  'item' => Icons.movie_outlined,
  _ => Icons.circle_outlined,
};

/// Distinct, legend-explained colour per relation (readable in light + dark).
const Map<String, Color> _relationColors = {
  'uploader': Color(0xFF42A5F5), // blue
  'playlist': Color(0xFFAB47BC), // purple
  'site': Color(0xFF26A69A), // teal
  'tag': Color(0xFFFFA726), // orange
  'duplicate': Color(0xFFEF5350), // red
  'codownload': Color(0xFF66BB6A), // green
  'item': Color(0xFF90A4AE), // blue-grey (media pulled by expanding an entity)
};

/// Colour for a relation's node/edge/legend chip.
Color relationColor(String relation) =>
    _relationColors[relation] ?? Colors.grey;

/// Entity relations expand to show their media; media relations navigate to the
/// item. `item` is a media node pulled by expanding an entity (P10c-f).
const Set<String> kEntityRelations = {'uploader', 'playlist', 'site', 'tag'};
bool isEntityRelation(String relation) => kEntityRelations.contains(relation);
bool isMediaRelation(String relation) => !isEntityRelation(relation);

/// Where tapping/opening a node leads: a media node → its item; an entity node →
/// its hub (uploader hubs key by *name* = [GraphNeighbor.label], the rest by id).
/// Pure → unit-testable. [extra] carries the hub's display name.
({String location, String? extra}) navTargetFor(GraphNeighbor n) {
  if (isMediaRelation(n.relation)) {
    return (location: '/item/${n.id}', extra: null);
  }
  final value = n.relation == 'uploader' ? n.label : n.id;
  return (
    location: Uri(
      path: '/hub/${n.relation}',
      queryParameters: {'v': value},
    ).toString(),
    extra: n.label,
  );
}

/// Builds the graph for the explorable neighborhood. The centre links to each
/// visible level-1 [neighbors]; an entity key present in [expanded] also links to
/// its pulled media children. Relations in [hiddenRelations] (and their children)
/// are skipped. Nodes are de-duplicated by key. Edge colour comes from [edgePaint]
/// (relation → Paint), supplied by the renderer so this stays theme-agnostic.
Graph buildNeighborhoodGraph({
  required String centerId,
  required List<GraphNeighbor> neighbors,
  Map<String, List<GraphNeighbor>> expanded = const {},
  Set<String> hiddenRelations = const {},
  Paint Function(String relation)? edgePaint,
}) {
  final graph = Graph();
  final nodes = <String, Node>{};
  Node nodeFor(String key) => nodes.putIfAbsent(key, () {
    final node = Node.Id(key);
    graph.addNode(node);
    return node;
  });

  final center = nodeFor(kCenterKey);
  for (final n in neighbors) {
    if (hiddenRelations.contains(n.relation)) continue;
    final key = neighborKey(n);
    graph.addEdge(center, nodeFor(key), paint: edgePaint?.call(n.relation));
    for (final child in expanded[key] ?? const <GraphNeighbor>[]) {
      graph.addEdge(
        nodeFor(key),
        nodeFor(neighborKey(child)),
        paint: edgePaint?.call(child.relation),
      );
    }
  }
  return graph;
}
