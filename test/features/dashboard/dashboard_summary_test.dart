import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/dashboard/presentation/dashboard_providers.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';

MediaItem _item({required String id, int? sizeBytes}) => MediaItem(
  id: id,
  title: id,
  sourceUrl: 'u',
  site: 'youtube',
  filePath: '/tmp/$id.mp4',
  type: 'video',
  sizeBytes: sizeBytes,
  createdAt: DateTime.utc(2026),
  storageState: 'private',
  isFavorite: false,
);

DownloadTask _task(String status) => DownloadTask(
  id: 't-$status',
  url: 'u',
  requestJson: '{}',
  status: status,
  progress: 0,
  retries: 0,
  createdAt: DateTime.utc(2026),
  orderIndex: 0,
);

Collection _collection(int id) =>
    Collection(id: id, name: 'c$id', createdAt: DateTime.utc(2026));

void main() {
  group('buildDashboardSummary', () {
    test('sums sizes and counts items, queue, and collections', () {
      final summary = buildDashboardSummary(
        items: [
          _item(id: 'a', sizeBytes: 100),
          _item(id: 'b', sizeBytes: 50),
          _item(id: 'c', sizeBytes: null), // null size counts as 0 bytes
        ],
        tasks: [
          _task(TaskStatus.running),
          _task(TaskStatus.queued),
          _task(TaskStatus.done), // excluded from pending
          _task(TaskStatus.canceled), // excluded from pending
        ],
        collections: [_collection(1), _collection(2)],
      );

      expect(summary.itemCount, 3);
      expect(summary.usedBytes, 150);
      expect(summary.queuePending, 2); // running + queued only
      expect(summary.queueRunning, 1);
      expect(summary.collectionCount, 2);
      expect(summary.isEmpty, isFalse);
    });

    test('is empty for a brand-new install', () {
      final summary = buildDashboardSummary(
        items: const [],
        tasks: const [],
        collections: const [],
      );
      expect(summary.isEmpty, isTrue);
      expect(summary.usedBytes, 0);
    });

    test('held and paused tasks still count as pending', () {
      final summary = buildDashboardSummary(
        items: const [],
        tasks: [_task(TaskStatus.held), _task(TaskStatus.paused)],
        collections: const [],
      );
      expect(summary.queuePending, 2);
      expect(summary.queueRunning, 0);
    });
  });
}
