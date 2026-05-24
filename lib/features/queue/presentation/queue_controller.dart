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
import 'package:grabbit/core/engine/info_json_parser.dart';
import 'package:grabbit/core/battery/battery_service.dart';
import 'package:grabbit/core/network/network_monitor.dart';
import 'package:grabbit/core/storage/disk_space_service.dart';
import 'package:grabbit/core/storage/media_storage.dart';
import 'package:grabbit/core/utils/media_type.dart';
import 'package:grabbit/core/utils/upload_date.dart';
import 'package:grabbit/features/library/data/library_repository.dart';
import 'package:grabbit/features/queue/data/completed_outputs.dart';
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
  final Map<String, double> _percents = {};
  Future<void> _pumpChain = Future.value();
  bool _serviceActive = false;

  QueueRepository get _repo => ref.read(queueRepositoryProvider);
  ForegroundService get _service => ref.read(foregroundServiceProvider);

  @override
  Future<void> build() async {
    _service.onStop = _onStopRequested;
    // Re-pump when the network changes so Wi-Fi-only tasks auto-start once an
    // unmetered network returns (_doPump re-checks the metered gate).
    final netSub = ref
        .read(networkMonitorProvider)
        .onChanged
        .listen((_) => _pump());
    // Likewise re-pump on battery changes so low-battery-paused tasks resume.
    final batSub = ref
        .read(batteryServiceProvider)
        .onChanged
        .listen((_) => _pump());
    ref.onDispose(() {
      netSub.cancel();
      batSub.cancel();
      for (final t in _retryTimers.values) {
        t.cancel();
      }
    });
    await _repo.reconcileRunning();
    await _pump();
  }

  /// The notification "Stop" action pauses everything currently running.
  void _onStopRequested() => pauseAll();

  /// Pauses every currently-running download.
  void pauseAll() {
    for (final id in _runners.keys.toList()) {
      pause(id);
    }
  }

  Future<void> enqueue(QueuedDownload download) async {
    await _repo.enqueue(download);
    await _pump();
  }

  /// Adds downloads to the batch "cart" (`held`) without starting them.
  Future<void> enqueueHeld(List<QueuedDownload> downloads) =>
      _repo.enqueueAll(downloads, status: TaskStatus.held);

  /// Starts a regular (immediate) batch of downloads now.
  Future<void> enqueueNow(List<QueuedDownload> downloads) async {
    await _repo.enqueueAll(downloads);
    await _pump();
  }

  /// Releases the held batch into the queue and starts running it.
  Future<void> startAll() async {
    await _repo.startAllHeld();
    await _pump();
  }

  /// Re-queues every paused download so the scheduler picks them back up.
  Future<void> resumeAll() async {
    await _repo.resumeAllPaused();
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
      // A cancel supersedes a concurrent pause request for the same task.
      _pausing.remove(id);
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

  /// Removes all finished (done/canceled) tasks; returns how many were cleared.
  Future<int> clearCompleted() => _repo.clearCompleted();

  Future<void> _pump() {
    _pumpChain = _pumpChain.then((_) => _doPump()).catchError((_) {});
    return _pumpChain;
  }

  Future<void> _doPump() async {
    final settings = await ref.read(settingsControllerProvider.future);
    final reason = await _blockedReason(settings);
    if (reason != QueuePauseReason.none) {
      // Only flag a pause when tasks are actually waiting to run.
      final waiting = await _repo.countByStatus(TaskStatus.queued) > 0;
      _setPauseReason(waiting ? reason : QueuePauseReason.none);
      await _syncService();
      return;
    }
    _setPauseReason(QueuePauseReason.none);
    while (await _repo.countByStatus(TaskStatus.running) <
        settings.maxConcurrentDownloads) {
      final next = await _repo.nextQueued();
      if (next == null) break;
      await _start(next);
    }
    await _syncService();
  }

  /// Which safety gate (if any) is holding new downloads back (P9f). Checked in
  /// priority order; mirrors the original Wi-Fi-only gate.
  Future<QueuePauseReason> _blockedReason(SettingsModel settings) async {
    if (settings.wifiOnly && !await _service.isUnmetered()) {
      return QueuePauseReason.metered;
    }
    if (settings.minFreeSpaceMb > 0) {
      final dir = await ref.read(mediaStorageProvider).mediaDirectory();
      final space = await ref.read(diskSpaceServiceProvider).query(dir.path);
      if (space.freeBytes < settings.minFreeSpaceMb * 1024 * 1024) {
        return QueuePauseReason.lowStorage;
      }
    }
    if (settings.pauseOnLowBattery) {
      final battery = ref.read(batteryServiceProvider);
      if (await battery.isPowerSave() ||
          await battery.level() < settings.lowBatteryThreshold) {
        return QueuePauseReason.lowBattery;
      }
    }
    return QueuePauseReason.none;
  }

  void _setPauseReason(QueuePauseReason reason) =>
      ref.read(queuePauseReasonProvider.notifier).set(reason);

  /// Starts/updates/stops the foreground service to mirror the running set.
  /// Service control is best-effort: a platform failure must never break the
  /// queue, and the `_serviceActive` flag only flips after the call succeeds so
  /// a failed start/stop is retried on the next sync.
  Future<void> _syncService() async {
    final running = await _repo.countByStatus(TaskStatus.running);
    try {
      if (running > 0) {
        final text = '$running download${running == 1 ? '' : 's'} in progress';
        final percent = _averagePercent();
        if (_serviceActive) {
          await _service.update(
            text,
            progress: percent,
            indeterminate: percent == 0,
          );
        } else {
          await _service.start(text);
          _serviceActive = true;
        }
      } else if (_serviceActive) {
        await _service.stop();
        _serviceActive = false;
      }
    } catch (_) {}
  }

  /// Mean progress across the tasks currently streaming, so the notification
  /// reflects the whole running set instead of whichever updated last.
  int _averagePercent() {
    if (_percents.isEmpty) return 0;
    final sum = _percents.values.fold<double>(0, (a, b) => a + b);
    return (sum / _percents.length).round();
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
            _percents[id] = p.percent;
            ref
                .read(queueLiveStatsProvider.notifier)
                .set(
                  id,
                  etaSec: p.etaSec,
                  speedBps: p.speedBps,
                  totalBytes: p.totalBytes,
                );
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
    _canceling.remove(id);
    if (_pausing.remove(id)) {
      await _repo.setStatus(id, TaskStatus.paused);
    } else {
      await _repo.setStatus(id, TaskStatus.canceled);
    }
    _finish(id);
    await _pump();
  }

  void _finish(String id) {
    _runners.remove(id);
    _percents.remove(id);
    ref.read(queueLiveStatsProvider.notifier).remove(id);
  }

  /// Persists a manual drag-reorder of the queue. [newIndex] is the destination
  /// already adjusted for the removed item (ReorderableListView `onReorderItem`).
  /// The watch stream re-emits in the new order, and `nextQueued` now respects
  /// `orderIndex` (P9d).
  Future<void> reorder(int oldIndex, int newIndex) async {
    final rows = await _repo.watch().first;
    final ids = [for (final r in rows) r.id];
    if (oldIndex < 0 || oldIndex >= ids.length) return;
    final id = ids.removeAt(oldIndex);
    ids.insert(newIndex.clamp(0, ids.length), id);
    await _repo.setOrder(ids);
  }

  Duration _backoff(int retries, QueueConfig config) {
    final ms = config.baseRetryDelay.inMilliseconds * (1 << retries);
    return Duration(
      milliseconds: ms.clamp(0, config.maxRetryDelay.inMilliseconds),
    );
  }

  Future<void> _persistCompleted(String id, QueuedDownload queued) async {
    // Files land in a per-task subfolder (see YtDlpHost `-o`): the task id names
    // the folder, the user's template names the file inside it.
    final dir = Directory('${queued.request.outputDir}/$id');
    if (!dir.existsSync()) return;
    final outputs = classifyDownloadOutputs(dir.listSync().whereType<File>());
    if (outputs.media.isEmpty) return;

    // Rich metadata from the .info.json sidecar (shared across split-chapter
    // files), falling back to whatever the queued item already carried.
    InfoJson? info;
    if (outputs.info != null) {
      info = parseInfoJsonString(await outputs.info!.readAsString());
    }
    final uploader = info?.uploader ?? queued.uploader;
    final description = info?.description ?? queued.description;
    final uploadDate = parseUploadDate(info?.uploadDate ?? queued.uploadDate);
    final hasMetadata =
        uploader != null ||
        description != null ||
        uploadDate != null ||
        queued.originalUrl != null ||
        queued.playlistId != null ||
        info?.uploaderId != null ||
        info?.sourceId != null ||
        info?.tags != null;

    final db = ref.read(appDatabaseProvider);
    // One library item per output file. `--split-chapters` yields N files, so
    // each gets a unique id + its filename as the title; a normal single-file
    // download keeps the task id and queued title unchanged.
    final single = outputs.media.length == 1;
    await db.transaction(() async {
      for (final (i, mediaFile) in outputs.media.indexed) {
        final itemId = single ? id : '${id}__$i';
        final ext = mediaFile.path.split('.').last.toLowerCase();
        await db
            .into(db.mediaItems)
            .insertOnConflictUpdate(
              MediaItemsCompanion.insert(
                id: itemId,
                title: single ? queued.title : _fileStem(mediaFile.path),
                sourceUrl: queued.request.url,
                site: queued.site ?? info?.extractor ?? 'unknown',
                filePath: mediaFile.path,
                type: queued.request.audioOnly ? 'audio' : mediaTypeForExt(ext),
                createdAt: DateTime.now(),
                storageState: 'private',
                durationSec: Value(single ? queued.durationSec : null),
                sizeBytes: Value(await mediaFile.length()),
                thumbPath: Value(outputs.thumb?.path),
              ),
            );
        if (hasMetadata) {
          await db
              .into(db.mediaMetadata)
              .insertOnConflictUpdate(
                MediaMetadataCompanion.insert(
                  itemId: itemId,
                  uploader: Value(uploader),
                  originalUrl: Value(queued.originalUrl),
                  description: Value(description),
                  uploadDate: Value(uploadDate),
                  uploaderId: Value(info?.uploaderId),
                  channelId: Value(info?.channelId),
                  sourceId: Value(info?.sourceId),
                  playlistId: Value(queued.playlistId),
                  playlistTitle: Value(queued.playlistTitle),
                  tags: Value(info?.tags),
                ),
              );
        }
      }
    });
  }

  /// Filename without directory or extension — the per-chapter title for splits.
  String _fileStem(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}

/// Transient per-task download stats (not persisted) for the queue dashboard.
typedef TaskLive = ({int? etaSec, double? speedBps, int? totalBytes});

/// Live speed/ETA/size per running task, fed from the engine progress stream
/// (P9d). Transient — cleared when a task finishes.
class QueueLiveStats extends Notifier<Map<String, TaskLive>> {
  @override
  Map<String, TaskLive> build() => const {};

  void set(String id, {int? etaSec, double? speedBps, int? totalBytes}) {
    state = {
      ...state,
      id: (etaSec: etaSec, speedBps: speedBps, totalBytes: totalBytes),
    };
  }

  void remove(String id) {
    if (!state.containsKey(id)) return;
    state = {...state}..remove(id);
  }
}

final queueLiveStatsProvider =
    NotifierProvider<QueueLiveStats, Map<String, TaskLive>>(QueueLiveStats.new);

/// Why the scheduler is currently holding new downloads back (P9f), surfaced as
/// a banner on the queue screen. `none` when nothing is gated.
enum QueuePauseReason { none, metered, lowStorage, lowBattery }

class QueuePauseReasonNotifier extends Notifier<QueuePauseReason> {
  @override
  QueuePauseReason build() => QueuePauseReason.none;

  void set(QueuePauseReason reason) {
    if (state != reason) state = reason;
  }
}

final queuePauseReasonProvider =
    NotifierProvider<QueuePauseReasonNotifier, QueuePauseReason>(
      QueuePauseReasonNotifier.new,
    );
