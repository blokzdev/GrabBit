import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/graph/community_clustering.dart';

List<({String item, String group})> _members(
  Map<String, List<String>> byGroup,
) => [
  for (final e in byGroup.entries)
    for (final item in e.value) (item: item, group: e.key),
];

void main() {
  group('detectCommunities', () {
    test('splits items into communities by shared entity buckets', () {
      final communities = detectCommunities(
        memberships: _members({
          't:rock': ['a', 'b', 'c'],
          't:jazz': ['d', 'e', 'f'],
        }),
        pairs: const [],
      );
      expect(communities, hasLength(2));
      expect(
        communities.map((c) => c.items.toSet()),
        containsAll([
          {'a', 'b', 'c'},
          {'d', 'e', 'f'},
        ]),
      );
      expect({for (final c in communities) c.dominantTag}, {'rock', 'jazz'});
    });

    test('merges items linked through a web of shared signals', () {
      // a–b share a tag, b–c share an uploader → one community {a,b,c}.
      final communities = detectCommunities(
        memberships: _members({
          't:live': ['a', 'b'],
          'u:chan1': ['b', 'c'],
        }),
        pairs: const [],
      );
      expect(communities, hasLength(1));
      expect(communities.single.items.toSet(), {'a', 'b', 'c'});
    });

    test('co-download pairs connect items directly', () {
      final communities = detectCommunities(
        memberships: const [],
        pairs: const [(a: 'a', b: 'b'), (a: 'b', b: 'c')],
      );
      expect(communities, hasLength(1));
      expect(communities.single.items.toSet(), {'a', 'b', 'c'});
      expect(communities.single.dominantTag, isNull);
    });

    test('drops communities below minSize', () {
      final communities = detectCommunities(
        memberships: _members({
          't:rock': ['a', 'b'], // only 2 → below default minSize 3
        }),
        pairs: const [],
      );
      expect(communities, isEmpty);
    });

    test('prunes over-generic buckets (> maxGroupSize)', () {
      // A mega-tag on 4 items with maxGroupSize 3 contributes no edges.
      final communities = detectCommunities(
        memberships: _members({
          't:everything': ['a', 'b', 'c', 'd'],
        }),
        pairs: const [],
        maxGroupSize: 3,
      );
      expect(communities, isEmpty);
    });

    test('dominant tag needs support >= 2; ties pick the smallest', () {
      final communities = detectCommunities(
        memberships: _members({
          'u:chan1': ['a', 'b', 'c'], // connects them
          't:alpha': ['a', 'b'], // support 2
          't:beta': ['b', 'c'], // support 2 → tie, "alpha" < "beta"
        }),
        pairs: const [],
      );
      expect(communities, hasLength(1));
      expect(communities.single.dominantTag, 'alpha');
    });

    test('is deterministic across runs', () {
      List<Community> run() => detectCommunities(
        memberships: _members({
          't:rock': ['c', 'a', 'b'],
          't:jazz': ['f', 'e', 'd'],
        }),
        // A single bridge edge does NOT merge two dense clusters under label
        // propagation (the point vs. raw connected-components) — two stay two.
        pairs: const [(a: 'b', b: 'd')],
      );
      final a = run();
      final b = run();
      expect(a.map((c) => c.items), b.map((c) => c.items));
      expect(a, hasLength(2));
      expect(a.map((c) => c.items.length), [3, 3]);
    });
  });
}
