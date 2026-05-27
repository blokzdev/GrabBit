import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/download_error.dart';
import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:grabbit/core/battery/battery_service.dart';
import 'package:grabbit/core/lifecycle/app_lifecycle_provider.dart';
import 'package:grabbit/core/network/network_monitor.dart';
import 'package:grabbit/core/storage/disk_space_service.dart';
import 'package:grabbit/core/storage/media_storage.dart';
import 'package:grabbit/features/notifications/data/notification_enums.dart';
import 'package:grabbit/features/notifications/data/system_notification_service.dart';
import 'package:grabbit/features/queue/data/foreground_service.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';
import 'package:grabbit/features/queue/data/queued_download.dart';
import 'package:grabbit/features/queue/presentation/queue_controller.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// Engine whose downloads stay "running" until the test pushes a terminal event.
class ControllableEngine implements DownloadEngine {
  final Map<String, StreamController<DownloadProgress>> _ctrls = {};

  Iterable<String> get running => _ctrls.keys;

  @override
  Stream<DownloadProgress> download(DownloadRequest request) {
    final c = StreamController<DownloadProgress>();
    _ctrls[request.taskId] = c;
    c.add(
      DownloadProgress(
        taskId: request.taskId,
        stage: DownloadStage.downloading,
        percent: 10,
      ),
    );
    return c.stream;
  }

  void progress(String id, {int? eta, double speed = 0, int? total}) {
    _ctrls[id]?.add(
      DownloadProgress(
        taskId: id,
        stage: DownloadStage.downloading,
        percent: 50,
        etaSec: eta,
        speedBps: speed,
        totalBytes: total,
      ),
    );
  }

  void complete(String id) {
    _ctrls.remove(id)
      ?..add(
        DownloadProgress(taskId: id, stage: DownloadStage.done, percent: 100),
      )
      ..close();
  }

  void fail(String id, DownloadErrorCode code) {
    _ctrls.remove(id)
      ?..add(
        DownloadProgress(
          taskId: id,
          stage: DownloadStage.error,
          errorCode: code,
        ),
      )
      ..close();
  }

  @override
  Future<void> cancel(String id) async {
    final c = _ctrls.remove(id);
    if (c != null) {
      c.add(DownloadProgress(taskId: id, stage: DownloadStage.canceled));
      await c.close();
    }
  }

  @override
  Future<MediaInfo> probe(String url) async =>
      const MediaInfo(title: '', formats: []);

  @override
  Future<PlaylistInfo> expand(String url) async => PlaylistInfo(
    entries: [MediaEntry(url: url, title: 'x')],
  );

  @override
  Future<EngineVersion> version() async =>
      const EngineVersion(ytDlp: '1', ffmpeg: '1');

  @override
  Future<void> update() async {}
}

class FakeForegroundService implements ForegroundService {
  int startCount = 0;
  int stopCount = 0;
  bool unmetered = true;
  void Function()? stopCallback;

  @override
  set onStop(void Function() callback) => stopCallback = callback;
  @override
  Future<void> start(
    String text, {
    int progress = 0,
    bool indeterminate = true,
  }) async => startCount++;
  @override
  Future<void> update(
    String text, {
    int progress = 0,
    bool indeterminate = false,
  }) async {}
  @override
  Future<void> stop() async => stopCount++;
  @override
  Future<bool> isUnmetered() async => unmetered;
}

/// Records OS-notification show calls so tests can assert on them.
class FakeSystemNotificationService implements SystemNotificationService {
  final List<({String taskId, String route, bool isError})> shown = [];

  @override
  Future<void> initialize({required void Function(String route) onTap}) async {}

  @override
  Future<void> showDownload({
    required String taskId,
    required String title,
    String? body,
    required String route,
    required bool isError,
  }) async {
    shown.add((taskId: taskId, route: route, isError: isError));
  }

  @override
  Future<String?> takeLaunchRoute() async => null;
}

/// Network monitor whose change events the test fires manually.
class FakeNetworkMonitor implements NetworkMonitor {
  final _controller = StreamController<void>.broadcast();
  void fireChange() => _controller.add(null);
  @override
  Stream<void> get onChanged => _controller.stream;
}

/// Disk-space probe with a settable free-byte value.
class FakeDiskSpaceService implements DiskSpaceService {
  int freeBytes = 1 << 40; // 1 TiB by default → never blocks
  @override
  Future<DiskSpace> query(String path) async =>
      (freeBytes: freeBytes, totalBytes: 1 << 40);
}

/// Battery probe with settable level / power-save and a manual change event.
class FakeBatteryService implements BatteryService {
  int batteryLevel = 100;
  bool powerSave = false;
  final _controller = StreamController<void>.broadcast();
  void fireChange() => _controller.add(null);
  @override
  Future<int> level() async => batteryLevel;
  @override
  Future<bool> isPowerSave() async => powerSave;
  @override
  Stream<void> get onChanged => _controller.stream;
}

/// MediaStorage pointed at a fixed temp dir (no path_provider in tests).
class FakeMediaStorage extends MediaStorage {
  FakeMediaStorage(this._dir);
  final Directory _dir;
  @override
  Future<Directory> mediaDirectory() async => _dir;
}

QueuedDownload _qd(
  String id, {
  String outputDir = '/tmp',
  bool audio = false,
  String? description,
  String? uploadDate,
}) {
  return QueuedDownload(
    request: DownloadRequest(
      taskId: id,
      url: 'https://example.com/$id',
      outputDir: outputDir,
      filenameTemplate: '%(title)s.%(ext)s',
      audioOnly: audio,
    ),
    title: 'Title $id',
    site: 'example',
    uploader: 'Channel $id',
    description: description,
    uploadDate: uploadDate,
  );
}

Future<void> waitFor(
  Future<bool> Function() cond, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (await cond()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError('condition not met within $timeout');
}

void main() {
  late AppDatabase db;
  late ControllableEngine engine;
  late ProviderContainer container;
  late QueueRepository repo;
  late QueueController controller;
  late FakeForegroundService fakeService;
  late FakeNetworkMonitor fakeNetwork;
  late FakeDiskSpaceService fakeDisk;
  late FakeBatteryService fakeBattery;
  late FakeSystemNotificationService fakeOsNotifier;
  late Directory mediaDir;

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      downloadEngineProvider.overrideWithValue(engine),
      foregroundServiceProvider.overrideWithValue(fakeService),
      networkMonitorProvider.overrideWithValue(fakeNetwork),
      diskSpaceServiceProvider.overrideWithValue(fakeDisk),
      batteryServiceProvider.overrideWithValue(fakeBattery),
      systemNotificationServiceProvider.overrideWithValue(fakeOsNotifier),
      mediaStorageProvider.overrideWithValue(FakeMediaStorage(mediaDir)),
      queueConfigProvider.overrideWithValue(
        const QueueConfig(baseRetryDelay: Duration(milliseconds: 5)),
      ),
    ],
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    engine = ControllableEngine();
    fakeService = FakeForegroundService();
    fakeNetwork = FakeNetworkMonitor();
    fakeDisk = FakeDiskSpaceService();
    fakeBattery = FakeBatteryService();
    fakeOsNotifier = FakeSystemNotificationService();
    mediaDir = Directory.systemTemp.createTempSync('grabbit_qmedia_');
    container = makeContainer();
    repo = container.read(queueRepositoryProvider);
    controller = container.read(queueControllerProvider.notifier);
    await container.read(queueControllerProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (mediaDir.existsSync()) mediaDir.deleteSync(recursive: true);
  });

  test('requestJson round-trips through QueuedDownload', () {
    final qd = _qd('t1', audio: true);
    final restored = QueuedDownload.fromJson(qd.toJson());
    expect(restored.request.taskId, 't1');
    expect(restored.request.audioOnly, isTrue);
    expect(restored.title, 'Title t1');
    expect(restored.site, 'example');
  });

  test('honors the concurrency cap (default 2)', () async {
    await controller.enqueue(_qd('t1'));
    await controller.enqueue(_qd('t2'));
    await controller.enqueue(_qd('t3'));

    await waitFor(() async => engine.running.length == 2);
    expect(await repo.countByStatus(TaskStatus.running), 2);
    expect(await repo.countByStatus(TaskStatus.queued), 1);

    // Completing one frees a slot for the third.
    engine.complete(engine.running.first);
    await waitFor(() async => engine.running.length == 2);
    expect(await repo.countByStatus(TaskStatus.running), 2);
  });

  test('retryable error re-enqueues with incremented retries', () async {
    await controller.enqueue(_qd('t1'));
    await waitFor(() async => engine.running.contains('t1'));

    engine.fail('t1', DownloadErrorCode.network);

    // Backoff (5ms) re-runs it; retries was bumped.
    await waitFor(() async => (await repo.byId('t1'))!.retries == 1);
    await waitFor(() async => engine.running.contains('t1'));
  });

  test('non-retryable error marks the task failed', () async {
    await controller.enqueue(_qd('t1'));
    await waitFor(() async => engine.running.contains('t1'));

    engine.fail('t1', DownloadErrorCode.unsupportedSite);

    await waitFor(
      () async => (await repo.byId('t1'))?.status == TaskStatus.error,
    );
    final task = await repo.byId('t1');
    expect(task!.errorCode, 'unsupportedSite');
    expect(task.retries, 0);
  });

  test('pause then resume', () async {
    await controller.enqueue(_qd('t1'));
    await waitFor(() async => engine.running.contains('t1'));

    await controller.pause('t1');
    await waitFor(
      () async => (await repo.byId('t1'))?.status == TaskStatus.paused,
    );

    await controller.resume('t1');
    await waitFor(() async => engine.running.contains('t1'));
  });

  test('completion persists a library item from output files', () async {
    final dir = await Directory.systemTemp.createTemp('grabbit_queue_');
    addTearDown(() => dir.delete(recursive: true));
    // Files land in a per-task subfolder named by the taskId.
    await Directory('${dir.path}/vid1').create();
    await File('${dir.path}/vid1/My Clip.mp4').writeAsString('data');
    await File('${dir.path}/vid1/My Clip.jpg').writeAsString('thumb');

    await controller.enqueue(_qd('vid1', outputDir: dir.path));
    await waitFor(() async => engine.running.contains('vid1'));
    engine.complete('vid1');

    await waitFor(
      () async => (await repo.byId('vid1'))?.status == TaskStatus.done,
    );
    final item = await (db.select(
      db.mediaItems,
    )..where((t) => t.id.equals('vid1'))).getSingleOrNull();
    expect(item, isNotNull);
    expect(item!.title, 'Title vid1');
    expect(item.type, 'video');
  });

  test('a completed download posts a success activity entry (P11c)', () async {
    final dir = await Directory.systemTemp.createTemp('grabbit_ntf_done_');
    addTearDown(() => dir.delete(recursive: true));
    await Directory('${dir.path}/vid1').create();
    await File('${dir.path}/vid1/My Clip.mp4').writeAsString('data');

    await controller.enqueue(_qd('vid1', outputDir: dir.path));
    await waitFor(() async => engine.running.contains('vid1'));
    engine.complete('vid1');

    await waitFor(
      () async => (await db.select(db.notifications).get()).isNotEmpty,
    );
    final n = (await db.select(db.notifications).get()).single;
    expect(n.category, NotificationCategory.download);
    expect(n.severity, NotificationSeverity.success);
    expect(n.taskId, 'vid1');
    expect(n.targetRoute, '/item/vid1');
  });

  test(
    'a terminal download failure posts an error activity entry (P11c)',
    () async {
      await controller.enqueue(_qd('t1'));
      await waitFor(() async => engine.running.contains('t1'));
      engine.fail('t1', DownloadErrorCode.unsupportedSite);

      await waitFor(
        () async => (await db.select(db.notifications).get()).isNotEmpty,
      );
      final n = (await db.select(db.notifications).get()).single;
      expect(n.category, NotificationCategory.download);
      expect(n.severity, NotificationSeverity.error);
      expect(n.taskId, 't1');
      expect(n.body, isNotNull);
      expect(n.targetRoute, '/queue');
    },
  );

  test('a backgrounded completion raises an OS notification (P11d)', () async {
    final dir = await Directory.systemTemp.createTemp('grabbit_os_done_');
    addTearDown(() => dir.delete(recursive: true));
    await Directory('${dir.path}/vid1').create();
    await File('${dir.path}/vid1/My Clip.mp4').writeAsString('data');

    container
        .read(appLifecycleStateProvider.notifier)
        .set(AppLifecycleState.paused);
    await controller.enqueue(_qd('vid1', outputDir: dir.path));
    await waitFor(() async => engine.running.contains('vid1'));
    engine.complete('vid1');

    await waitFor(() async => fakeOsNotifier.shown.isNotEmpty);
    final n = fakeOsNotifier.shown.single;
    expect(n.taskId, 'vid1');
    expect(n.route, '/item/vid1');
    expect(n.isError, isFalse);
  });

  test('a backgrounded failure raises an OS notification (P11d)', () async {
    container
        .read(appLifecycleStateProvider.notifier)
        .set(AppLifecycleState.paused);
    await controller.enqueue(_qd('t1'));
    await waitFor(() async => engine.running.contains('t1'));
    engine.fail('t1', DownloadErrorCode.unsupportedSite);

    await waitFor(() async => fakeOsNotifier.shown.isNotEmpty);
    final n = fakeOsNotifier.shown.single;
    expect(n.taskId, 't1');
    expect(n.route, '/queue');
    expect(n.isError, isTrue);
  });

  test('a foregrounded completion raises no OS notification (P11d)', () async {
    final dir = await Directory.systemTemp.createTemp('grabbit_os_fg_');
    addTearDown(() => dir.delete(recursive: true));
    await Directory('${dir.path}/vid1').create();
    await File('${dir.path}/vid1/My Clip.mp4').writeAsString('data');

    // Lifecycle defaults to resumed; the in-app inbox already covers this case.
    await controller.enqueue(_qd('vid1', outputDir: dir.path));
    await waitFor(() async => engine.running.contains('vid1'));
    engine.complete('vid1');

    // Wait for the inbox entry (the producer ran), then assert no OS popup.
    await waitFor(
      () async => (await db.select(db.notifications).get()).isNotEmpty,
    );
    expect(fakeOsNotifier.shown, isEmpty);
  });

  test('muting download notifications suppresses the OS popup but keeps the '
      'inbox error record (P11d)', () async {
    await container
        .read(settingsControllerProvider.notifier)
        .setNotifyDownload(false);
    container
        .read(appLifecycleStateProvider.notifier)
        .set(AppLifecycleState.paused);
    await controller.enqueue(_qd('t1'));
    await waitFor(() async => engine.running.contains('t1'));
    engine.fail('t1', DownloadErrorCode.unsupportedSite);

    // Errors always record in the inbox, even with the toggle off.
    await waitFor(
      () async => (await db.select(db.notifications).get()).isNotEmpty,
    );
    expect(fakeOsNotifier.shown, isEmpty);
  });

  test('a canceled download posts no activity entry (P11c)', () async {
    await controller.enqueue(_qd('t1'));
    await waitFor(() async => engine.running.contains('t1'));
    await controller.cancelAll();
    await waitFor(
      () async => (await repo.byId('t1'))?.status == TaskStatus.canceled,
    );
    // Give any stray async post a chance to land, then assert none did.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await db.select(db.notifications).get(), isEmpty);
  });

  test(
    'completion writes description + uploadDate to media_metadata',
    () async {
      final dir = await Directory.systemTemp.createTemp('grabbit_meta_');
      addTearDown(() => dir.delete(recursive: true));
      await Directory('${dir.path}/m1').create();
      await File('${dir.path}/m1/clip.mp4').writeAsString('data');

      await controller.enqueue(
        _qd(
          'm1',
          outputDir: dir.path,
          description: 'A clip',
          uploadDate: '20240115',
        ),
      );
      await waitFor(() async => engine.running.contains('m1'));
      engine.complete('m1');
      await waitFor(
        () async => (await repo.byId('m1'))?.status == TaskStatus.done,
      );

      final meta = await (db.select(
        db.mediaMetadata,
      )..where((t) => t.itemId.equals('m1'))).getSingle();
      expect(meta.uploader, 'Channel m1');
      expect(meta.description, 'A clip');
      expect(meta.uploadDate!.toUtc(), DateTime.utc(2024, 1, 15));
    },
  );

  test('enriches metadata from the .info.json sidecar', () async {
    final dir = await Directory.systemTemp.createTemp('grabbit_info_');
    addTearDown(() => dir.delete(recursive: true));
    await Directory('${dir.path}/b1').create();
    await File('${dir.path}/b1/clip.mp4').writeAsString('data');
    await File('${dir.path}/b1/clip.info.json').writeAsString(
      '{"id":"vid42","uploader":"Cool Channel","uploader_id":"@cool",'
      '"channel_id":"UC9","upload_date":"20240115","extractor_key":"Youtube",'
      '"tags":["a","b"]}',
    );

    // A batch-style item: no uploader/site of its own, but a playlist identity.
    final qd = QueuedDownload(
      request: DownloadRequest(
        taskId: 'b1',
        url: 'https://example.com/b1',
        outputDir: dir.path,
        filenameTemplate: '%(title)s.%(ext)s',
      ),
      title: 'Clip',
      playlistId: 'PL7',
      playlistTitle: 'My Playlist',
    );
    await controller.enqueue(qd);
    await waitFor(() async => engine.running.contains('b1'));
    engine.complete('b1');
    await waitFor(
      () async => (await repo.byId('b1'))?.status == TaskStatus.done,
    );

    final item = await (db.select(
      db.mediaItems,
    )..where((t) => t.id.equals('b1'))).getSingle();
    expect(item.site, 'Youtube'); // from info.json extractor

    final meta = await (db.select(
      db.mediaMetadata,
    )..where((t) => t.itemId.equals('b1'))).getSingle();
    expect(meta.uploader, 'Cool Channel');
    expect(meta.uploaderId, '@cool');
    expect(meta.channelId, 'UC9');
    expect(meta.sourceId, 'vid42');
    expect(meta.tags, 'a, b');
    expect(meta.playlistId, 'PL7');
    expect(meta.playlistTitle, 'My Playlist');
    expect(meta.uploadDate!.toUtc(), DateTime.utc(2024, 1, 15));
  });

  test(
    'runs the foreground service while downloading, stops when drained',
    () async {
      await controller.enqueue(_qd('t1'));
      await waitFor(() async => engine.running.contains('t1'));
      expect(fakeService.startCount, greaterThanOrEqualTo(1));

      engine.complete('t1');
      await waitFor(() async => fakeService.stopCount >= 1);
    },
  );

  test('wifiOnly keeps tasks queued on a metered network', () async {
    await container.read(settingsControllerProvider.notifier).setWifiOnly(true);
    fakeService.unmetered = false;

    await controller.enqueue(_qd('t1'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(engine.running, isEmpty);
    expect(await repo.countByStatus(TaskStatus.queued), 1);
  });

  test('resumes Wi-Fi-only tasks when an unmetered network returns', () async {
    await container.read(settingsControllerProvider.notifier).setWifiOnly(true);
    fakeService.unmetered = false;

    await controller.enqueue(_qd('t1'));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(engine.running, isEmpty); // blocked on a metered network

    // Network flips to unmetered and emits a change → the queue re-pumps.
    fakeService.unmetered = true;
    fakeNetwork.fireChange();
    await waitFor(() async => engine.running.contains('t1'));
  });

  test('enqueueHeld holds items without starting them', () async {
    await controller.enqueueHeld([_qd('h1'), _qd('h2')]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(engine.running, isEmpty);
    expect(await repo.countByStatus(TaskStatus.held), 2);
  });

  test('enqueueNow starts a batch immediately', () async {
    await controller.enqueueNow([_qd('n1'), _qd('n2')]);
    await waitFor(() async => engine.running.length == 2);
    expect(await repo.countByStatus(TaskStatus.running), 2);
  });

  test('startAll releases the held batch and runs it', () async {
    await controller.enqueueHeld([_qd('h1'), _qd('h2')]);
    await controller.startAll();
    await waitFor(() async => engine.running.length == 2);
    expect(await repo.countByStatus(TaskStatus.held), 0);
  });

  test('retryAllFailed re-queues every errored task (P9i)', () async {
    await db
        .into(db.downloadTasks)
        .insert(
          DownloadTasksCompanion.insert(
            id: 'e1',
            url: 'u',
            requestJson: '{}',
            status: TaskStatus.error,
            createdAt: DateTime.now(),
          ),
        );
    await db
        .into(db.downloadTasks)
        .insert(
          DownloadTasksCompanion.insert(
            id: 'e2',
            url: 'u',
            requestJson: '{}',
            status: TaskStatus.error,
            createdAt: DateTime.now(),
          ),
        );
    await controller.retryAllFailed();
    expect(await repo.countByStatus(TaskStatus.error), 0);
  });

  test(
    'clearFinished removes done/canceled/error, keeps active (P9i)',
    () async {
      Future<void> insert(String id, String status) => db
          .into(db.downloadTasks)
          .insert(
            DownloadTasksCompanion.insert(
              id: id,
              url: 'u',
              requestJson: '{}',
              status: status,
              createdAt: DateTime.now(),
            ),
          );
      await insert('d1', TaskStatus.done);
      await insert('c1', TaskStatus.canceled);
      await insert('e1', TaskStatus.error);
      await insert('q1', TaskStatus.queued);

      final cleared = await controller.clearFinished();
      expect(cleared, 3);
      expect(await repo.byId('q1'), isNotNull);
    },
  );

  test('cancelAll cancels active tasks (P9i)', () async {
    await controller.enqueue(_qd('t1'));
    await controller.enqueue(_qd('t2'));
    await controller.enqueue(_qd('t3')); // 2 run, 1 queued
    await waitFor(() async => engine.running.length == 2);

    await controller.cancelAll();
    await waitFor(
      () async => await repo.countByStatus(TaskStatus.running) == 0,
    );
    expect(await repo.countByStatus(TaskStatus.queued), 0);
  });

  test('resumeAll re-queues every paused download', () async {
    await controller.enqueue(_qd('t1'));
    await controller.enqueue(_qd('t2'));
    await waitFor(() async => engine.running.length == 2);

    controller.pauseAll();
    await waitFor(() async => await repo.countByStatus(TaskStatus.paused) == 2);

    await controller.resumeAll();
    await waitFor(() async => engine.running.length == 2);
    expect(await repo.countByStatus(TaskStatus.paused), 0);
  });

  test('pauseAll pauses every running download', () async {
    await controller.enqueue(_qd('t1'));
    await controller.enqueue(_qd('t2'));
    await waitFor(() async => engine.running.length == 2);

    controller.pauseAll();
    await waitFor(() async => await repo.countByStatus(TaskStatus.paused) == 2);
    expect(engine.running, isEmpty);
  });

  test('clearCompleted removes done/canceled but keeps active tasks', () async {
    Future<void> insert(String id, String status) => db
        .into(db.downloadTasks)
        .insert(
          DownloadTasksCompanion.insert(
            id: id,
            url: 'https://example.com/$id',
            requestJson: '{}',
            status: status,
            createdAt: DateTime.now(),
          ),
        );
    await insert('d1', TaskStatus.done);
    await insert('c1', TaskStatus.canceled);
    await insert('q1', TaskStatus.queued);
    await insert('e1', TaskStatus.error);

    final cleared = await controller.clearCompleted();

    expect(cleared, 2);
    expect(await repo.byId('d1'), isNull);
    expect(await repo.byId('c1'), isNull);
    expect(await repo.byId('q1'), isNotNull);
    expect(await repo.byId('e1'), isNotNull);
  });

  test('reconcileRunning flips orphaned running tasks to queued', () async {
    await db
        .into(db.downloadTasks)
        .insert(
          DownloadTasksCompanion.insert(
            id: 'orphan',
            url: 'https://example.com/orphan',
            requestJson: '{}',
            status: TaskStatus.running,
            createdAt: DateTime.now(),
          ),
        );
    await repo.reconcileRunning();
    expect((await repo.byId('orphan'))!.status, TaskStatus.queued);
  });

  test('enqueueAll assigns distinct, increasing orderIndex', () async {
    await controller.enqueueHeld([_qd('h1'), _qd('h2'), _qd('h3')]);
    final rows = await repo.watch().first;
    final byId = {for (final r in rows) r.id: r.orderIndex};
    expect(byId['h1']! < byId['h2']!, isTrue);
    expect(byId['h2']! < byId['h3']!, isTrue);
  });

  test('reorder persists a new queue order via setOrder', () async {
    await controller.enqueueHeld([_qd('h1'), _qd('h2'), _qd('h3')]);
    expect(
      [for (final r in await repo.watch().first) r.id],
      ['h1', 'h2', 'h3'],
    );

    // Drag the first item to the end.
    await controller.reorder(0, 2);
    expect(
      [for (final r in await repo.watch().first) r.id],
      ['h2', 'h3', 'h1'],
    );
  });

  test(
    'a progress event populates queueLiveStats; completion clears it',
    () async {
      await controller.enqueue(_qd('t1'));
      await waitFor(() async => engine.running.contains('t1'));

      engine.progress('t1', eta: 42, speed: 1024, total: 2048);
      await waitFor(
        () async =>
            container.read(queueLiveStatsProvider)['t1']?.speedBps == 1024,
      );
      final live = container.read(queueLiveStatsProvider)['t1']!;
      expect(live.etaSec, 42);
      expect(live.totalBytes, 2048);

      engine.complete('t1');
      await waitFor(
        () async => !container.read(queueLiveStatsProvider).containsKey('t1'),
      );
    },
  );

  test('nextQueued and watch respect orderIndex after setOrder', () async {
    // A repo-only db so the controller's scheduler doesn't claim queued tasks.
    final db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(db2.close);
    final repo2 = QueueRepository(db2);

    await repo2.enqueueAll([_qd('a'), _qd('b'), _qd('c')]);
    expect((await repo2.nextQueued())!.id, 'a');

    await repo2.setOrder(['c', 'b', 'a']);
    expect((await repo2.nextQueued())!.id, 'c');
    expect([for (final r in await repo2.watch().first) r.id], ['c', 'b', 'a']);
  });

  test('low storage holds tasks queued until space frees up', () async {
    fakeDisk.freeBytes = 100 * 1024 * 1024; // 100 MB < default 500 MB
    await controller.enqueue(_qd('t1'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(engine.running, isEmpty);
    expect(await repo.countByStatus(TaskStatus.queued), 1);
    expect(
      container.read(queuePauseReasonProvider),
      QueuePauseReason.lowStorage,
    );

    fakeDisk.freeBytes = 1 << 40; // space freed
    fakeNetwork.fireChange(); // any signal re-pumps
    await waitFor(() async => engine.running.contains('t1'));
    expect(container.read(queuePauseReasonProvider), QueuePauseReason.none);
  });

  test('minFreeSpaceMb = 0 disables the storage guard', () async {
    await container
        .read(settingsControllerProvider.notifier)
        .setMinFreeSpaceMb(0);
    fakeDisk.freeBytes = 1; // effectively nothing free
    await controller.enqueue(_qd('t1'));
    await waitFor(() async => engine.running.contains('t1'));
  });

  test('low battery holds tasks until the battery recovers', () async {
    await container
        .read(settingsControllerProvider.notifier)
        .setPauseOnLowBattery(true);
    fakeBattery.batteryLevel = 5; // below default 15%
    await controller.enqueue(_qd('t1'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(engine.running, isEmpty);
    expect(
      container.read(queuePauseReasonProvider),
      QueuePauseReason.lowBattery,
    );

    fakeBattery.batteryLevel = 80;
    fakeBattery.fireChange();
    await waitFor(() async => engine.running.contains('t1'));
  });

  test('moveToTop / moveToBottom reorder the queue (P9g)', () async {
    final db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(db2.close);
    final repo2 = QueueRepository(db2);
    await repo2.enqueueAll([_qd('a'), _qd('b'), _qd('c')]);

    // Reuse the controller's helper against a stand-in repo via a fresh
    // container so the scheduler doesn't claim the queued tasks.
    final container2 = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db2),
        downloadEngineProvider.overrideWithValue(ControllableEngine()),
        foregroundServiceProvider.overrideWithValue(FakeForegroundService()),
        networkMonitorProvider.overrideWithValue(FakeNetworkMonitor()),
        diskSpaceServiceProvider.overrideWithValue(FakeDiskSpaceService()),
        batteryServiceProvider.overrideWithValue(FakeBatteryService()),
        mediaStorageProvider.overrideWithValue(FakeMediaStorage(mediaDir)),
        // Hold everything so the scheduler leaves the order intact.
        queueConfigProvider.overrideWithValue(const QueueConfig()),
      ],
    );
    addTearDown(container2.dispose);
    final c2 = container2.read(queueControllerProvider.notifier);
    await container2.read(queueControllerProvider.future);

    await c2.moveToBottom('a');
    expect([for (final r in await repo2.watch().first) r.id], ['b', 'c', 'a']);

    await c2.moveToTop('a');
    expect([for (final r in await repo2.watch().first) r.id], ['a', 'b', 'c']);
  });

  test('power-save mode holds downloads when the gate is on', () async {
    await container
        .read(settingsControllerProvider.notifier)
        .setPauseOnLowBattery(true);
    fakeBattery.powerSave = true;
    await controller.enqueue(_qd('t1'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(engine.running, isEmpty);
    expect(
      container.read(queuePauseReasonProvider),
      QueuePauseReason.lowBattery,
    );
  });
}
