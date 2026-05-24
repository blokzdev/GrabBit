import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/queue/data/queued_download.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persistent download-queue states (`download_tasks.status`).
abstract final class TaskStatus {
  static const queued = 'queued';
  static const running = 'running';
  static const paused = 'paused';
  static const done = 'done';
  static const error = 'error';
  static const canceled = 'canceled';

  /// In a batch "cart" — never auto-started until the user taps "Start all".
  static const held = 'held';
}

/// CRUD + streaming over the `download_tasks` table.
class QueueRepository {
  QueueRepository(this._db);

  final AppDatabase _db;

  Stream<List<DownloadTask>> watch() =>
      (_db.select(_db.downloadTasks)..orderBy([
            (t) => OrderingTerm.asc(t.orderIndex),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
          .watch();

  Future<DownloadTask?> byId(String id) => (_db.select(
    _db.downloadTasks,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> countByStatus(String status) async {
    final count = _db.downloadTasks.id.count();
    final query = _db.selectOnly(_db.downloadTasks)
      ..addColumns([count])
      ..where(_db.downloadTasks.status.equals(status));
    return (await query.getSingle()).read(count) ?? 0;
  }

  Future<DownloadTask?> nextQueued() =>
      (_db.select(_db.downloadTasks)
            ..where((t) => t.status.equals(TaskStatus.queued))
            ..orderBy([
              (t) => OrderingTerm.asc(t.orderIndex),
              (t) => OrderingTerm.asc(t.createdAt),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<int> _maxOrderIndex() async {
    final max = _db.downloadTasks.orderIndex.max();
    final query = _db.selectOnly(_db.downloadTasks)..addColumns([max]);
    return (await query.getSingleOrNull())?.read(max) ?? 0;
  }

  /// Persists a new queue order: writes `orderIndex` = position for each id.
  Future<void> setOrder(List<String> idsInOrder) async {
    await _db.batch((batch) {
      for (var i = 0; i < idsInOrder.length; i++) {
        batch.update(
          _db.downloadTasks,
          DownloadTasksCompanion(orderIndex: Value(i)),
          where: (t) => t.id.equals(idsInOrder[i]),
        );
      }
    });
  }

  Future<void> enqueue(
    QueuedDownload download, {
    String status = TaskStatus.queued,
  }) => enqueueAll([download], status: status);

  /// Inserts a batch of downloads in one transaction (status applies to all).
  Future<void> enqueueAll(
    List<QueuedDownload> downloads, {
    String status = TaskStatus.queued,
  }) async {
    if (downloads.isEmpty) return;
    final now = DateTime.now();
    // Append after existing tasks with distinct, increasing order indices so the
    // queue can be reordered (P9d).
    final base = await _maxOrderIndex() + 1;
    await _db.batch((batch) {
      for (var i = 0; i < downloads.length; i++) {
        final d = downloads[i];
        batch.insert(
          _db.downloadTasks,
          DownloadTasksCompanion.insert(
            id: d.request.taskId,
            url: d.request.url,
            requestJson: jsonEncode(d.toJson()),
            status: status,
            // Preserve insertion order within a batch added at the same instant.
            createdAt: now.add(Duration(milliseconds: i)),
            orderIndex: Value(base + i),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Flips every `held` task to `queued` (the scheduler then runs them).
  Future<void> startAllHeld() async {
    await (_db.update(_db.downloadTasks)
          ..where((t) => t.status.equals(TaskStatus.held)))
        .write(const DownloadTasksCompanion(status: Value(TaskStatus.queued)));
  }

  /// Flips every `paused` task back to `queued` so the scheduler resumes them.
  Future<void> resumeAllPaused() async {
    await (_db.update(_db.downloadTasks)
          ..where((t) => t.status.equals(TaskStatus.paused)))
        .write(const DownloadTasksCompanion(status: Value(TaskStatus.queued)));
  }

  Future<void> setStatus(String id, String status, {String? errorCode}) async {
    await (_db.update(_db.downloadTasks)..where((t) => t.id.equals(id))).write(
      DownloadTasksCompanion(
        status: Value(status),
        errorCode: Value(errorCode),
      ),
    );
  }

  Future<void> setProgress(String id, double progress) async {
    await (_db.update(_db.downloadTasks)..where((t) => t.id.equals(id))).write(
      DownloadTasksCompanion(progress: Value(progress)),
    );
  }

  Future<void> bumpRetries(String id) async {
    await _db.customUpdate(
      'UPDATE download_tasks SET retries = retries + 1 WHERE id = ?',
      variables: [Variable<String>(id)],
      updates: {_db.downloadTasks},
    );
  }

  Future<void> remove(String id) async {
    await (_db.delete(_db.downloadTasks)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes finished tasks (done/canceled); returns how many were removed.
  Future<int> clearCompleted() =>
      (_db.delete(_db.downloadTasks)..where(
            (t) => t.status.isIn(const [TaskStatus.done, TaskStatus.canceled]),
          ))
          .go();

  /// On startup, any task left `running` was orphaned by process death — requeue.
  Future<void> reconcileRunning() async {
    await (_db.update(_db.downloadTasks)
          ..where((t) => t.status.equals(TaskStatus.running)))
        .write(const DownloadTasksCompanion(status: Value(TaskStatus.queued)));
  }
}

final queueRepositoryProvider = Provider<QueueRepository>(
  (ref) => QueueRepository(ref.watch(appDatabaseProvider)),
);

/// Live stream of all queue tasks for the queue screen.
final queueTasksProvider = StreamProvider<List<DownloadTask>>(
  (ref) => ref.watch(queueRepositoryProvider).watch(),
);
