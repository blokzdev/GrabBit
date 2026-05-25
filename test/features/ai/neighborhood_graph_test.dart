import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/graph/graph_query_service.dart';
import 'package:grabbit/features/ai/presentation/neighborhood_graph.dart';

GraphNeighbor _n(String relation, String id) =>
    GraphNeighbor(relation: relation, id: id, label: '$relation $id');

void main() {
  test('neighborKey is unique per relation+id', () {
    expect(neighborKey(_n('tag', 'x')), 'tag::x');
    expect(neighborKey(_n('uploader', 'x')), 'uploader::x');
  });

  test('builds a star graph: centre + one node/edge per neighbor', () {
    final neighbors = [_n('uploader', 'u1'), _n('tag', 't1'), _n('site', 'yt')];
    final graph = buildNeighborhoodGraph(centerId: 'a', neighbors: neighbors);
    expect(graph.nodeCount(), 1 + neighbors.length);
    expect(graph.edges.length, neighbors.length);
    // Every edge runs from the centre node.
    expect(graph.edges.every((e) => e.source.key!.value == kCenterKey), isTrue);
  });

  test('no neighbors → just the centre node, no edges', () {
    final graph = buildNeighborhoodGraph(centerId: 'a', neighbors: const []);
    expect(graph.nodeCount(), 1);
    expect(graph.edges, isEmpty);
  });
}
