import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/download_error.dart';
import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:grabbit/features/library/data/library_repository.dart';
import 'package:grabbit/features/queue/data/foreground_service.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';
import 'package:grabbit/features/queue/data/queued_download.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'queue_controller.g.dart';

class QueueConfig {
  const QueueConfig({
    this.baseRetryDelay = const Duration(seconds: 2),
    this.maxRetryDelay = const Duration(seconds: 60),
    this.maxRetries = 3,
  });

  final Duration baseRetryDelay;
  final Duration maxRetryDelay;
  final int maxRetries;
}

final queueConfigProvider = Provider<QueueConfig>((ref) => const QueueConfig());

/// Drives the persistent download queue: schedules up to
/// `maxConcurrentDownloads` at once, retries transient failures with backoff,
/// supports pause/resume/cancel, and reconciles orphaned tasks on startup.
@Riverpod(keepAlive: true)
class QueueController extends _$QueueController {
  final Map<String, Future<void>> _runners = {};
  final Set<String> _pausing = {};
  final Set<String> _canceling = {};
  final Map<String, Timer> _retryTimers = {};
  Future<void> _pumpChain = Future.value();
  bool _serviceActive = false;
  int _lastPercent = 0;

  QueueRepository get _repo => ref.read(queueRepositoryProvider);
  ForegroundService get _service => ref.read(foregroundServiceProvider);

  @override
  Future<void> build() async {
    _service.onStop = _onStopRequested;
    ref.onDispose(() {
      for (final t in _retryTimers.values) {
        t.cancel();
      }
    });
    await _repo.reconcileRunning();
    await _pump();
  }

  /// The notification "Stop" action pauses everything currently running.
  void _onStopRequested() {
    for (final id in _runners.keys.toList()) {
      pause(id);
    }
  }

  Future<void> enqueue(QueuedDownload download) async {
    await _repo.enqueue(download);
    await _pump();
  }

  Future<void> pause(String id) async {
    if (_runners.containsKey(id)) {
      _pausing.add(id);
      await ref.read(downloadEngineProvider).cancel(id);
    } else {
      await _repo.setStatus(id, TaskStatus.paused);
    }
  }

  Future<void> resume(String id) async {
    await _repo.setStatus(id, TaskStatus.queued);
    await _pump();
  }

  Future<void> retry(String id) async {
    await _repo.setStatus(id, TaskStatus.queued);
    await _pump();
  }

  Future<void> cancel(String id) async {
    _retryTimers.remove(id)?.cancel();
    if (_runners.containsKey(id)) {
      _canceling.add(id);
      await ref.read(downloadEngineProvider).cancel(id);
    } else {
      await _repo.setStatus(id, TaskStatus.canceled);
    }
  }

  Future<void> remove(String id) async {
    _retryTimers.remove(id)?.cancel();
    await _repo.remove(id);
  }

  Future<void> _pump() {
    _pumpChain = _pumpChain.then((_) => _doPump()).catchError((_) {});
    return _pumpChain;
  }

  Future<void> _doPump() async {
    final settings = await ref.read(settingsControllerProvider.future);
    if (settings.wifiOnly && !await _service.isUnmetered()) {
      await _syncService();
      return;
    }
    while (await _repo.countByStatus(TaskStatus.running) <
        settings.maxConcurrentDownloads) {
      final next = await _repo.nextQueued();
      if (next == null) break;
      await _start(next);
    }
    await _syncService();
  }

  /// Starts/updates/stops the foreground service to mirror the running set.
  Future<void> _syncService() async {
    final running = await _repo.countByStatus(TaskStatus.running);
    if (running > 0) {
      final text = '$running download${running == 1 ? '' : 's'} in progress';
      if (_serviceActive) {
        await _service.update(
          text,
          progress: _lastPercent,
          indeterminate: _lastPercent == 0,
        );
      } else {
        _serviceActive = true;
        await _service.start(text);
      }
    } else if (_serviceActive) {
      _serviceActive = false;
      await _service.stop();
    }
  }

  Future<void> _start(DownloadTask task) async {
    await _repo.setStatus(task.id, TaskStatus.running);
    final queued = QueuedDownload.fromJson(
      jsonDecode(task.requestJson) as Map<String, dynamic>,
    );
    _runners[task.id] = _run(task.id, queued);
  }

  Future<void> _run(String id, QueuedDownload queued) async {
    final engine = ref.read(downloadEngineProvider);
    try {
      await for (final p in engine.download(queued.request)) {
        switch (p.stage) {
          case DownloadStage.done:
            await _onDone(id, queued);
            return;
          case DownloadStage.error:
            await _onError(id, p.errorCode);
            return;
          case DownloadStage.canceled:
            await _onCanceled(id);
            return;
          case DownloadStage.probing:
          case DownloadStage.downloading:
          case DownloadStage.merging:
            _lastPercent = p.percent.round();
            await _repo.setProgress(id, p.percent);
            await _syncService();
        }
      }
    } catch (_) {
      await _onError(id, DownloadErrorCode.unknown);
    }
  }

  Future<void> _onDone(String id, QueuedDownload queued) async {
    await _persistCompleted(id, queued);
    await _repo.setProgress(id, 100);
    await _repo.setStatus(id, TaskStatus.done);
    _finish(id);
    await _maybeAutoExport(id);
    await _pump();
  }

  Future<void> _maybeAutoExport(String id) async {
    final settings = await ref.read(settingsControllerProvider.future);
    if (settings.storagePolicy != StoragePolicy.autoExport) return;
    final db = ref.read(appDatabaseProvider);
    final item = await (db.select(
      db.mediaItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (item == null) return;
    // Export failure must not fail the download.
    try {
      await ref
          .read(libraryRepositoryProvider)
          .export(item, treeUri: settings.exportFolder);
    } catch (_) {}
  }

  Future<void> _onError(String id, DownloadErrorCode? code) async {
    final task = await _repo.byId(id);
    final config = ref.read(queueConfigProvider);
    final retryable = (code ?? DownloadErrorCode.unknown).isRetryable;
    if (task != null && retryable && task.retries < config.maxRetries) {
      await _repo.bumpRetries(id);
      await _repo.setStatus(id, TaskStatus.queued);
      _finish(id);
      final delay = _backoff(task.retries, config);
      _retryTimers[id] = Timer(delay, () {
        _retryTimers.remove(id);
        _pump();
      });
    } else {
      await _repo.setStatus(id, TaskStatus.error, errorCode: code?.name);
      _finish(id);
      await _pump();
    }
  }

  Future<void> _onCanceled(String id) async {
    if (_pausing.remove(id)) {
      await _repo.setStatus(id, TaskStatus.paused);
    } else {
      _canceling.remove(id);
      await _repo.setStatus(id, TaskStatus.canceled);
    }
    _finish(id);
    await _pump();
  }

  void _finish(String id) => _runners.remove(id);

  Duration _backoff(int retries, QueueConfig config) {
    final ms = config.baseRetryDelay.inMilliseconds * (1 << retries);
    return Duration(
      milliseconds: ms.clamp(0, config.maxRetryDelay.inMilliseconds),
    );
  }

  Future<void> _persistCompleted(String id, QueuedDownload queued) async {
    final dir = Directory(queued.request.outputDir);
    if (!dir.existsSync()) return;
    File? thumb;
    File? media;
    for (final entry in dir.listSync().whereType<File>()) {
      if (!entry.uri.pathSegments.last.startsWith('$id.')) continue;
      if (entry.path.toLowerCase().endsWith('.jpg')) {
        thumb = entry;
      } else {
        media = entry;
      }
    }
    if (media == null) return;

    final ext = media.path.split('.').last.toLowerCase();
    final db = ref.read(appDatabaseProvider);
    final mediaFile = media;
    await db.transaction(() async {
      await db
          .into(db.mediaItems)
          .insertOnConflictUpdate(
            MediaItemsCompanion.insert(
              id: id,
              title: queued.title,
              sourceUrl: queued.request.url,
              site: queued.site ?? 'unknown',
              filePath: mediaFile.path,
              type: queued.request.audioOnly ? 'audio' : _typeForExt(ext),
              createdAt: DateTime.now(),
              storageState: 'private',
              durationSec: Value(queued.durationSec),
              sizeBytes: Value(await mediaFile.length()),
              thumbPath: Value(thumb?.path),
            ),
          );
      if (queued.uploader != null || queued.originalUrl != null) {
        await db
            .into(db.mediaMetadata)
            .insertOnConflictUpdate(
              MediaMetadataCompanion.insert(
                itemId: id,
                uploader: Value(queued.uploader),
                originalUrl: Value(queued.originalUrl),
              ),
            );
      }
    });
  }
}

String _typeForExt(String ext) {
  const image = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
  const audio = {'m4a', 'mp3', 'opus', 'aac', 'ogg', 'wav'};
  if (image.contains(ext)) return 'image';
  if (audio.contains(ext)) return 'audio';
  return 'video';
}
