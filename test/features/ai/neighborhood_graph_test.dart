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

  group('navTargetFor', () {
    test('media relations navigate to the item', () {
      for (final rel in ['duplicate', 'codownload', 'item']) {
        final t = navTargetFor(_n(rel, 'm1'));
        expect(t.location, '/item/m1');
        expect(t.extra, isNull);
      }
    });

    test('uploader hub keys by name (label); others by id', () {
      final up = navTargetFor(
        const GraphNeighbor(relation: 'uploader', id: 'UC123', label: 'Rick'),
      );
      expect(up.location, '/hub/uploader?v=Rick');
      expect(up.extra, 'Rick');

      final pl = navTargetFor(
        const GraphNeighbor(relation: 'playlist', id: 'PL1', label: 'Mix'),
      );
      expect(pl.location, '/hub/playlist?v=PL1');
      expect(pl.extra, 'Mix');
    });
  });

  group('expand + filter', () {
    test('an expanded entity links to its media children', () {
      final uploader = _n('uploader', 'u1');
      final graph = buildNeighborhoodGraph(
        centerId: 'a',
        neighbors: [uploader],
        expanded: {
          neighborKey(uploader): [_n('item', 'm1'), _n('item', 'm2')],
        },
      );
      expect(graph.nodeCount(), 4); // centre + uploader + 2 media
      expect(graph.edges.length, 3); // centre→uploader, uploader→m1/m2
    });

    test('hiddenRelations drops the neighbor and its children', () {
      final tag = _n('tag', 't1');
      final graph = buildNeighborhoodGraph(
        centerId: 'a',
        neighbors: [tag, _n('uploader', 'u1')],
        expanded: {
          neighborKey(tag): [_n('item', 'm1')],
        },
        hiddenRelations: {'tag'},
      );
      expect(graph.nodeCount(), 2); // centre + uploader only
      expect(graph.edges.length, 1);
    });

    test('a media child shared by two entities is added once', () {
      final uploader = _n('uploader', 'u1');
      final tag = _n('tag', 't1');
      final shared = _n('item', 'm1');
      final graph = buildNeighborhoodGraph(
        centerId: 'a',
        neighbors: [uploader, tag],
        expanded: {
          neighborKey(uploader): [shared],
          neighborKey(tag): [shared],
        },
      );
      // centre + uploader + tag + m1 = 4 nodes; edges: 2 (centre→u/t) + 2 (u/t→m1)
      expect(graph.nodeCount(), 4);
      expect(graph.edges.length, 4);
    });
  });
}
