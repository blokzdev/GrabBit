import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/graph/related_ranking.dart';

({String id, double distance}) hit(String id, double d) =>
    (id: id, distance: d);
({String id, RelatedSignal signal}) sig(String id, RelatedSignal s) =>
    (id: id, signal: s);

void main() {
  group('blendRelated', () {
    test('vector-only: ranks nearest (smallest distance) first', () {
      final ranked = blendRelated(
        vectorHits: [hit('b', 0.1), hit('c', 0.5)],
        signals: const [],
      );
      expect(ranked, ['b', 'c']);
    });

    test('graph-only works with no vector hits', () {
      final ranked = blendRelated(
        vectorHits: const [],
        signals: [
          sig('b', RelatedSignal.uploader),
          sig('c', RelatedSignal.tag),
        ],
      );
      // uploader (0.5) outranks a single tag (0.15).
      expect(ranked, ['b', 'c']);
    });

    test('shared tags accrue but are capped', () {
      final ranked = blendRelated(
        vectorHits: const [],
        signals: [
          // 4 shared tags → capped at 3 × 0.15 = 0.45 (< uploader 0.5).
          for (var i = 0; i < 4; i++) sig('c', RelatedSignal.tag),
          sig('b', RelatedSignal.uploader),
        ],
      );
      expect(ranked, ['b', 'c']);
    });

    test('blends vector similarity with graph boosts', () {
      // c is closer by vector, but b adds an uploader boost and wins.
      final ranked = blendRelated(
        vectorHits: [hit('b', 0.2), hit('c', 0.1)],
        signals: [sig('b', RelatedSignal.uploader)],
      );
      expect(ranked.first, 'b');
      expect(ranked, containsAll(['b', 'c']));
    });

    test('excludes the source id and duplicates', () {
      final ranked = blendRelated(
        vectorHits: [hit('a', 0.0), hit('d', 0.05), hit('b', 0.3)],
        signals: const [],
        exclude: {'a', 'd'},
      );
      expect(ranked, ['b']);
    });

    test('honours the limit', () {
      final ranked = blendRelated(
        vectorHits: [for (var i = 0; i < 20; i++) hit('item$i', i / 100)],
        signals: const [],
        limit: 5,
      );
      expect(ranked, hasLength(5));
      expect(ranked.first, 'item0');
    });

    test('ignores unknown signal kinds', () {
      expect(RelatedSignal.fromKind('mystery'), isNull);
    });
  });
}
