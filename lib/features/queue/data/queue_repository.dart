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
}

/// CRUD + streaming over the `download_tasks` table.
class QueueRepository {
  QueueRepository(this._db);

  final AppDatabase _db;

  Stream<List<DownloadTask>> watch() => (_db.select(
    _db.downloadTasks,
  )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();

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
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<void> enqueue(QueuedDownload download) async {
    await _db
        .into(_db.downloadTasks)
        .insert(
          DownloadTasksCompanion.insert(
            id: download.request.taskId,
            url: download.request.url,
            requestJson: jsonEncode(download.toJson()),
            status: TaskStatus.queued,
            createdAt: DateTime.now(),
          ),
        );
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
