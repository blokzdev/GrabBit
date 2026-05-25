/// At-a-glance counts for the Dashboard's stat tiles. A pure value object so the
/// aggregation logic that builds it stays unit-testable without Flutter/Riverpod.
class DashboardSummary {
  const DashboardSummary({
    required this.itemCount,
    required this.usedBytes,
    required this.queuePending,
    required this.queueRunning,
    required this.collectionCount,
  });

  /// Saved library items.
  final int itemCount;

  /// Sum of on-device file sizes across the library.
  final int usedBytes;

  /// Queue tasks that are neither finished nor canceled (waiting + active).
  final int queuePending;

  /// Queue tasks currently downloading.
  final int queueRunning;

  /// User collections.
  final int collectionCount;

  /// A brand-new install with nothing to show yet.
  bool get isEmpty =>
      itemCount == 0 && queuePending == 0 && collectionCount == 0;

  @override
  bool operator ==(Object other) =>
      other is DashboardSummary &&
      other.itemCount == itemCount &&
      other.usedBytes == usedBytes &&
      other.queuePending == queuePending &&
      other.queueRunning == queueRunning &&
      other.collectionCount == collectionCount;

  @override
  int get hashCode => Object.hash(
    itemCount,
    usedBytes,
    queuePending,
    queueRunning,
    collectionCount,
  );
}
