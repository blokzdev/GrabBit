import 'package:grabbit/core/db/database.dart';

/// Sentinel `colorIndex` for the aggregated "Other" donut slice. The widget
/// layer maps it to a muted neutral so "Other" reads as distinct from the real,
/// palette-colored slices. Real slices use indices `0..n-1`.
const int kOtherColorIndex = -1;

/// One slice of a storage donut. Colour is expressed as a palette [colorIndex]
/// (resolved in the widget layer) so this stays Flutter-free and unit-testable.
class DonutSlice {
  const DonutSlice({
    required this.label,
    required this.bytes,
    required this.fraction,
    required this.colorIndex,
  });

  final String label;
  final int bytes;

  /// Share of the donut total, `0.0..1.0`.
  final double fraction;
  final int colorIndex;

  @override
  bool operator ==(Object other) =>
      other is DonutSlice &&
      other.label == label &&
      other.bytes == bytes &&
      other.fraction == fraction &&
      other.colorIndex == colorIndex;

  @override
  int get hashCode => Object.hash(label, bytes, fraction, colorIndex);
}

/// Ordered donut slices plus the total, so the widget can show a centre label
/// and a legend without recomputing.
class DonutData {
  const DonutData({required this.slices, required this.totalBytes});

  final List<DonutSlice> slices;
  final int totalBytes;

  bool get isEmpty => slices.isEmpty || totalBytes == 0;
}

/// One bar of the activity series: a calendar day and how many items were added.
class ActivityBucket {
  const ActivityBucket({required this.start, required this.count});

  /// The bucket's day at local midnight.
  final DateTime start;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is ActivityBucket && other.start == start && other.count == count;

  @override
  int get hashCode => Object.hash(start, count);
}

/// A continuous, zero-filled run of [ActivityBucket]s (oldest → newest).
class ActivitySeries {
  const ActivitySeries({required this.buckets});

  final List<ActivityBucket> buckets;

  int get total => buckets.fold(0, (a, b) => a + b.count);
  bool get isEmpty => total == 0;
}

/// Builds a donut from a `{label: bytes}` map (e.g. `sizeByType`/`sizeBySite`).
///
/// Drops non-positive entries; sorts descending by bytes (ties broken by label
/// ascending for determinism); keeps the top [maxSlices] and, if strictly more
/// positive entries remain, sums the rest into one trailing "[otherLabel]" slice
/// ([kOtherColorIndex]). Empty/all-zero input yields an [DonutData.isEmpty] result.
DonutData buildDonut(
  Map<String, int> byKey, {
  int maxSlices = 5,
  String otherLabel = 'Other',
}) {
  final positive = byKey.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) {
      final byBytes = b.value.compareTo(a.value);
      return byBytes != 0 ? byBytes : a.key.compareTo(b.key);
    });
  final total = positive.fold<int>(0, (a, e) => a + e.value);
  if (positive.isEmpty || total == 0) {
    return const DonutData(slices: [], totalBytes: 0);
  }

  final slices = <DonutSlice>[];
  final keep = positive.length > maxSlices ? maxSlices : positive.length;
  for (var i = 0; i < keep; i++) {
    final e = positive[i];
    slices.add(
      DonutSlice(
        label: e.key,
        bytes: e.value,
        fraction: e.value / total,
        colorIndex: i,
      ),
    );
  }
  if (positive.length > maxSlices) {
    final otherBytes = positive
        .skip(maxSlices)
        .fold<int>(0, (a, e) => a + e.value);
    slices.add(
      DonutSlice(
        label: otherLabel,
        bytes: otherBytes,
        fraction: otherBytes / total,
        colorIndex: kOtherColorIndex,
      ),
    );
  }
  return DonutData(slices: slices, totalBytes: total);
}

/// Buckets [items] by their `createdAt` calendar day into a zero-filled series
/// of the last [days] days ending on [now] (inclusive). Items outside the window
/// or dated in the future are ignored. Day matching is date-only (DST-safe), and
/// [now] is injectable for deterministic tests.
ActivitySeries buildActivitySeries(
  List<MediaItem> items, {
  required DateTime now,
  int days = 30,
}) {
  // Normalised day-start list; DateTime(y, m, d - k) normalises across months.
  final starts = [
    for (var i = 0; i < days; i++)
      DateTime(now.year, now.month, now.day - (days - 1) + i),
  ];
  final indexByKey = {for (var i = 0; i < days; i++) _dayKey(starts[i]): i};

  final counts = List<int>.filled(days, 0);
  for (final item in items) {
    final idx = indexByKey[_dayKey(item.createdAt)];
    if (idx != null) counts[idx]++;
  }

  return ActivitySeries(
    buckets: [
      for (var i = 0; i < days; i++)
        ActivityBucket(start: starts[i], count: counts[i]),
    ],
  );
}

int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
