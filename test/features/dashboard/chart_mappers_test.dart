import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/dashboard/domain/chart_mappers.dart';

MediaItem _item(DateTime createdAt) => MediaItem(
  id: createdAt.toIso8601String(),
  title: 't',
  sourceUrl: 'u',
  site: 'youtube',
  filePath: '/tmp/x',
  type: 'video',
  sizeBytes: 1,
  createdAt: createdAt,
  storageState: 'private',
  isFavorite: false,
);

void main() {
  group('buildDonut', () {
    test('orders slices by bytes desc and sums fractions to ~1', () {
      final d = buildDonut({'video': 300, 'audio': 100, 'image': 100});
      expect(d.totalBytes, 500);
      expect(d.slices.map((s) => s.label).toList(), [
        'video',
        'audio',
        'image',
      ]);
      expect(d.slices.map((s) => s.colorIndex).toList(), [0, 1, 2]);
      expect(d.slices.first.fraction, closeTo(0.6, 1e-9));
      final sum = d.slices.fold<double>(0, (a, s) => a + s.fraction);
      expect(sum, closeTo(1.0, 1e-9));
      expect(d.isEmpty, isFalse);
    });

    test('drops zero/negative entries', () {
      final d = buildDonut({'video': 100, 'audio': 0, 'image': -5});
      expect(d.slices.length, 1);
      expect(d.totalBytes, 100);
    });

    test('exactly maxSlices entries → no Other slice', () {
      final d = buildDonut({'a': 3, 'b': 2, 'c': 1}, maxSlices: 3);
      expect(d.slices.length, 3);
      expect(d.slices.any((s) => s.colorIndex == kOtherColorIndex), isFalse);
    });

    test('more than maxSlices → top-N kept + one trailing Other', () {
      final d = buildDonut({
        'a': 50,
        'b': 40,
        'c': 30,
        'd': 20,
        'e': 10,
        'f': 5,
      }, maxSlices: 3);
      expect(d.slices.length, 4); // 3 + Other
      expect(d.slices.take(3).map((s) => s.label).toList(), ['a', 'b', 'c']);
      final other = d.slices.last;
      expect(other.label, 'Other');
      expect(other.colorIndex, kOtherColorIndex);
      expect(other.bytes, 20 + 10 + 5); // d + e + f
    });

    test('ties broken by label ascending (deterministic)', () {
      final d = buildDonut({'b': 10, 'a': 10}, maxSlices: 5);
      expect(d.slices.map((s) => s.label).toList(), ['a', 'b']);
    });

    test('empty and all-zero maps are isEmpty', () {
      expect(buildDonut(const {}).isEmpty, isTrue);
      expect(buildDonut(const {'a': 0, 'b': 0}).isEmpty, isTrue);
    });

    test('single entry → one full slice', () {
      final d = buildDonut({'only': 42});
      expect(d.slices.single.fraction, 1.0);
      expect(d.slices.single.colorIndex, 0);
    });
  });

  group('buildActivitySeries', () {
    final now = DateTime(2026, 5, 25, 14, 30); // mid-afternoon

    test('returns exactly `days` zero-filled buckets, oldest→newest', () {
      final s = buildActivitySeries(const [], now: now, days: 7);
      expect(s.buckets.length, 7);
      expect(s.isEmpty, isTrue);
      expect(s.buckets.first.start, DateTime(2026, 5, 19));
      expect(s.buckets.last.start, DateTime(2026, 5, 25));
      expect(s.buckets.every((b) => b.count == 0), isTrue);
    });

    test('buckets items into the correct calendar day', () {
      final s = buildActivitySeries(
        [
          _item(DateTime(2026, 5, 25, 9)),
          _item(DateTime(2026, 5, 25, 23)), // same day, different time
          _item(DateTime(2026, 5, 20, 1)),
        ],
        now: now,
        days: 7,
      );
      expect(s.total, 3);
      expect(s.buckets.last.count, 2); // 2026-05-25
      expect(
        s.buckets.firstWhere((b) => b.start == DateTime(2026, 5, 20)).count,
        1,
      );
    });

    test('ignores items outside the window and in the future', () {
      final s = buildActivitySeries(
        [
          _item(DateTime(2026, 5, 1)), // older than 7-day window
          _item(DateTime(2026, 6, 1)), // future
        ],
        now: now,
        days: 7,
      );
      expect(s.total, 0);
    });
  });

  group('value equality', () {
    test('DonutSlice and ActivityBucket compare by value', () {
      expect(
        const DonutSlice(label: 'a', bytes: 1, fraction: 0.5, colorIndex: 0),
        const DonutSlice(label: 'a', bytes: 1, fraction: 0.5, colorIndex: 0),
      );
      expect(
        ActivityBucket(start: DateTime(2026, 5, 25), count: 2),
        ActivityBucket(start: DateTime(2026, 5, 25), count: 2),
      );
    });
  });
}
