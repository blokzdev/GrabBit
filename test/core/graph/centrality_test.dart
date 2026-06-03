import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/graph/centrality.dart';

List<({String item, String group})> _members(
  Map<String, List<String>> byGroup,
) => [
  for (final e in byGroup.entries)
    for (final item in e.value) (item: item, group: e.key),
];

void main() {
  group('buildItemGraph', () {
    test('accumulates weight across shared buckets + co-download', () {
      final adj = buildItemGraph(
        memberships: _members({
          't:rock': ['a', 'b'],
          'u:chan1': ['a', 'b'], // a–b share two buckets
        }),
        pairs: const [(a: 'a', b: 'b')], // ...and a direct edge
      );
      expect(adj['a']!['b'], 3);
      expect(adj['b']!['a'], 3); // symmetric
    });

    test('drops over-generic buckets (> maxGroupSize)', () {
      final adj = buildItemGraph(
        memberships: _members({
          't:everything': ['a', 'b', 'c', 'd'],
        }),
        pairs: const [],
        maxGroupSize: 3,
      );
      expect(adj, isEmpty);
    });
  });

  group('pageRank', () {
    test('a hub outranks its leaves', () {
      // Star: h connected to a,b,c,d; leaves touch only h.
      final adj = buildItemGraph(
        memberships: const [],
        pairs: const [
          (a: 'h', b: 'a'),
          (a: 'h', b: 'b'),
          (a: 'h', b: 'c'),
          (a: 'h', b: 'd'),
        ],
      );
      final pr = pageRank(adj);
      expect(pr['h']! > pr['a']!, isTrue);
      expect(pr['a'], closeTo(pr['b']!, 1e-9)); // symmetric leaves tie
    });

    test('is deterministic across runs', () {
      final adj = buildItemGraph(
        memberships: _members({
          't:rock': ['a', 'b', 'c'],
        }),
        pairs: const [(a: 'c', b: 'd')],
      );
      expect(pageRank(adj), pageRank(adj));
    });

    test('empty graph yields no scores', () {
      expect(pageRank(const {}), isEmpty);
    });

    test('handles a dangling node without blowing up', () {
      final pr = pageRank({
        'a': {'b': 1},
        'b': <String, num>{}, // dangling (no out-edges)
      });
      expect(pr.keys.toSet(), {'a', 'b'});
      expect(pr.values.every((v) => v.isFinite), isTrue);
      expect(pr.values.reduce((s, v) => s + v), closeTo(1.0, 1e-6));
    });
  });
}
