import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/dashboard/domain/dashboard_summary.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';

/// Pure fold of the canonical library/queue/collection lists into the
/// Dashboard's [DashboardSummary]. Kept top-level (no provider machinery) so it
/// is directly unit-testable with plain Drift rows.
DashboardSummary buildDashboardSummary({
  required List<MediaItem> items,
  required List<DownloadTask> tasks,
  required List<Collection> collections,
}) {
  var usedBytes = 0;
  for (final item in items) {
    usedBytes += item.sizeBytes ?? 0;
  }
  final pending = tasks
      .where(
        (t) => t.status != TaskStatus.done && t.status != TaskStatus.canceled,
      )
      .length;
  final running = tasks.where((t) => t.status == TaskStatus.running).length;
  return DashboardSummary(
    itemCount: items.length,
    usedBytes: usedBytes,
    queuePending: pending,
    queueRunning: running,
    collectionCount: collections.length,
  );
}

/// Composes the existing library/queue/collection streams into the Dashboard's
/// summary. Hand-written (it watches Drift-row-typed providers) per CLAUDE.md §8.
/// Surfaces loading until all three sources have a value and propagates the
/// first error so the screen can offer a single retry.
final dashboardSummaryProvider = Provider<AsyncValue<DashboardSummary>>((ref) {
  final items = ref.watch(libraryItemsProvider);
  final tasks = ref.watch(queueTasksProvider);
  final collections = ref.watch(collectionsProvider);

  final error = items.error ?? tasks.error ?? collections.error;
  if (error != null) {
    return AsyncError(
      error,
      items.stackTrace ??
          tasks.stackTrace ??
          collections.stackTrace ??
          StackTrace.current,
    );
  }

  final itemsValue = items.asData?.value;
  final tasksValue = tasks.asData?.value;
  final collectionsValue = collections.asData?.value;
  if (itemsValue == null || tasksValue == null || collectionsValue == null) {
    return const AsyncLoading();
  }

  return AsyncData(
    buildDashboardSummary(
      items: itemsValue,
      tasks: tasksValue,
      collections: collectionsValue,
    ),
  );
});
