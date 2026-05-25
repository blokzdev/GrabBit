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
};

/// Colour for a relation's node/edge/legend chip.
Color relationColor(String relation) =>
    _relationColors[relation] ?? Colors.grey;

/// Builds a star graph: the centre item linked to one node per neighbor. Edge
/// colour comes from [edgePaint] (relation → Paint), supplied by the renderer so
/// this stays theme-agnostic. Node widgets are produced by the GraphView builder
/// keyed on [kCenterKey] / [neighborKey].
Graph buildNeighborhoodGraph({
  required String centerId,
  required List<GraphNeighbor> neighbors,
  Paint Function(String relation)? edgePaint,
}) {
  final graph = Graph();
  final center = Node.Id(kCenterKey);
  graph.addNode(center);
  for (final n in neighbors) {
    final node = Node.Id(neighborKey(n));
    graph.addNode(node);
    graph.addEdge(center, node, paint: edgePaint?.call(n.relation));
  }
  return graph;
}
