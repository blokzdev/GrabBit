import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/graph/path_finding.dart';

List<({String item, String group})> _members(
  Map<String, List<String>> byGroup,
) => [
  for (final e in byGroup.entries)
    for (final item in e.value) (item: item, group: e.key),
];

void main() {
  group('findItemPath', () {
    test('direct shared bucket → one connector', () {
      final path = findItemPath(
        source: 'a',
        target: 'b',
        memberships: _members({
          'u:chan1': ['a', 'b'],
        }),
        pairs: const [],
      );
      expect(path, isNotNull);
      expect(path!.itemIds, ['a', 'b']);
      expect(path.connectors, ['same channel']);
    });

    test('multi-hop chain across different signals', () {
      final path = findItemPath(
        source: 'a',
        target: 'c',
        memberships: _members({
          'u:chan1': ['a', 'b'],
          't:blender': ['b', 'c'],
        }),
        pairs: const [],
      );
      expect(path!.itemIds, ['a', 'b', 'c']);
      expect(path.connectors, ['same channel', "shared tag 'blender'"]);
    });

    test('co-download is a direct item edge', () {
      final path = findItemPath(
        source: 'a',
        target: 'b',
        memberships: const [],
        pairs: const [(a: 'a', b: 'b')],
      );
      expect(path!.itemIds, ['a', 'b']);
      expect(path.connectors, ['downloaded together']);
    });

    test('connector labels per kind', () {
      String connector(String group) => findItemPath(
        source: 'a',
        target: 'b',
        memberships: _members({
          group: ['a', 'b'],
        }),
        pairs: const [],
      )!.connectors.single;
      expect(connector('u:1'), 'same channel');
      expect(connector('p:1'), 'same playlist');
      expect(connector('t:jazz'), "shared tag 'jazz'");
    });

    test('disconnected items → null', () {
      final path = findItemPath(
        source: 'a',
        target: 'z',
        memberships: _members({
          'u:chan1': ['a', 'b'],
        }),
        pairs: const [],
      );
      expect(path, isNull);
    });

    test('same source and target → null', () {
      final path = findItemPath(
        source: 'a',
        target: 'a',
        memberships: _members({
          'u:chan1': ['a', 'b'],
        }),
        pairs: const [],
      );
      expect(path, isNull);
    });

    test('over-generic bucket is skipped (no spurious link)', () {
      // A mega-tag on 4 items would otherwise 2-hop-link any pair.
      final path = findItemPath(
        source: 'a',
        target: 'd',
        memberships: _members({
          't:everything': ['a', 'b', 'c', 'd'],
        }),
        pairs: const [],
        maxGroupSize: 3,
      );
      expect(path, isNull);
    });

    test('is deterministic and picks the shortest path', () {
      // a–b directly co-downloaded; also a long way round via tags.
      GraphPath? run() => findItemPath(
        source: 'a',
        target: 'b',
        memberships: _members({
          't:x': ['a', 'm'],
          't:y': ['m', 'n'],
          't:z': ['n', 'b'],
        }),
        pairs: const [(a: 'a', b: 'b')],
      );
      final p1 = run();
      final p2 = run();
      expect(p1!.itemIds, p2!.itemIds);
      expect(p1.itemIds, ['a', 'b']); // direct edge beats the 3-hop detour
      expect(p1.connectors, ['downloaded together']);
    });
  });
}
