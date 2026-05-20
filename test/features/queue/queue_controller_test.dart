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
import 'package:grabbit/features/queue/data/queue_repository.dart';
import 'package:grabbit/features/queue/data/queued_download.dart';
import 'package:grabbit/features/queue/presentation/queue_controller.dart';

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
  Future<EngineVersion> version() async =>
      const EngineVersion(ytDlp: '1', ffmpeg: '1');

  @override
  Future<void> update() async {}
}

QueuedDownload _qd(String id, {String outputDir = '/tmp', bool audio = false}) {
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

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      downloadEngineProvider.overrideWithValue(engine),
      queueConfigProvider.overrideWithValue(
        const QueueConfig(baseRetryDelay: Duration(milliseconds: 5)),
      ),
    ],
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    engine = ControllableEngine();
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
    await File('${dir.path}/vid1.mp4').writeAsString('data');
    await File('${dir.path}/vid1.jpg').writeAsString('thumb');

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
