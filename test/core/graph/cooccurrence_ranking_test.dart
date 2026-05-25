import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/graph/cooccurrence_ranking.dart';

void main() {
  group('rankCoOccurringTags', () {
    test('counts distinct sources per tag and orders by support desc', () {
      final ranked = rankCoOccurringTags([
        (source: 'a', tag: 'music'),
        (source: 'b', tag: 'music'),
        (source: 'a', tag: 'live'),
      ]);
      expect(ranked.map((t) => t.tag), ['music', 'live']);
      expect(ranked.first.count, 2);
      expect(ranked.last.count, 1);
    });

    test('a single source cannot inflate a tag (dedups pairs)', () {
      final ranked = rankCoOccurringTags([
        (source: 'a', tag: 'music'),
        (source: 'a', tag: 'music'),
      ]);
      expect(ranked.single.count, 1);
    });

    test('breaks count ties alphabetically', () {
      final ranked = rankCoOccurringTags([
        (source: 'a', tag: 'zeta'),
        (source: 'b', tag: 'alpha'),
      ]);
      expect(ranked.map((t) => t.tag), ['alpha', 'zeta']);
    });

    test('excludes given tags and respects the limit', () {
      final ranked = rankCoOccurringTags(
        [
          (source: 'a', tag: 'self'),
          (source: 'a', tag: 'one'),
          (source: 'b', tag: 'two'),
          (source: 'c', tag: 'three'),
        ],
        exclude: {'self'},
        limit: 2,
      );
      expect(ranked, hasLength(2));
      expect(ranked.map((t) => t.tag), isNot(contains('self')));
    });

    test('empty input yields no tags', () {
      expect(rankCoOccurringTags(const []), isEmpty);
    });
  });
}
