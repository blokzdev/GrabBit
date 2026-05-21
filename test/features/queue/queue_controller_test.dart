import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/download_error.dart';
import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:grabbit/core/network/network_monitor.dart';
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

/// Network monitor whose change events the test fires manually.
class FakeNetworkMonitor implements NetworkMonitor {
  final _controller = StreamController<void>.broadcast();
  void fireChange() => _controller.add(null);
  @override
  Stream<void> get onChanged => _controller.stream;
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

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      downloadEngineProvider.overrideWithValue(engine),
      foregroundServiceProvider.overrideWithValue(fakeService),
      networkMonitorProvider.overrideWithValue(fakeNetwork),
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
    container = makeContainer();
    repo = container.read(queueRepositoryProvider);
    controller = container.read(queueControllerProvider.notifier);
    await container.read(queueControllerProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
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
}
