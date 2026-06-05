import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/library/presentation/rediscover.dart';

void main() {
  final now = DateTime.utc(2026, 6, 1);
  DateTime daysAgo(int d) => now.subtract(Duration(days: d));

  group('rankRediscover', () {
    test('excludes freshly-touched items, keeps stale central ones', () {
      final ranked = rankRediscover(
        centrality: {'a': 0.5, 'b': 0.3, 'c': 0.2},
        lastTouchById: {
          'a': daysAgo(60), // stale
          'b': daysAgo(2), // fresh -> excluded
          'c': daysAgo(60), // stale
        },
        now: now,
      );
      expect(ranked, ['a', 'c']); // by score, b dropped
    });

    test('staleness lifts an older item over a more central recent one', () {
      final ranked = rankRediscover(
        centrality: {'x': 0.6, 'y': 0.5},
        lastTouchById: {
          'x': daysAgo(20), // staleness 20/30
          'y': daysAgo(60), // staleness capped at 1
        },
        now: now,
      );
      // x: 0.6 * 0.667 = 0.40 ; y: 0.5 * 1 = 0.50 -> y first
      expect(ranked, ['y', 'x']);
    });

    test('caps the result at limit', () {
      final ranked = rankRediscover(
        centrality: {for (var i = 0; i < 20; i++) 'i$i': 1.0 - i / 100},
        lastTouchById: {for (var i = 0; i < 20; i++) 'i$i': daysAgo(40)},
        now: now,
        limit: 5,
      );
      expect(ranked, hasLength(5));
    });

    test('skips items with no centrality or no known touch time', () {
      final ranked = rankRediscover(
        centrality: {'a': 0.5, 'b': 0.5},
        lastTouchById: {'a': daysAgo(40)}, // b has no touch time
        now: now,
      );
      expect(ranked, ['a']);
    });

    test('empty input yields empty', () {
      expect(
        rankRediscover(centrality: const {}, lastTouchById: const {}, now: now),
        isEmpty,
      );
    });
  });
}
