import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:grabbit/core/network/network_monitor.dart';
import 'package:grabbit/core/storage/media_storage.dart';
import 'package:grabbit/features/downloader/presentation/downloader_controller.dart';
import 'package:grabbit/features/downloader/presentation/selection_controller.dart';
import 'package:grabbit/features/queue/data/foreground_service.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';
import 'package:grabbit/features/queue/presentation/queue_controller.dart';

/// Engine returning a configurable number of expanded entries, and a fixed
/// single-item probe result.
class _FakeEngine implements DownloadEngine {
  _FakeEngine(this.entryCount);
  final int entryCount;

  @override
  Future<PlaylistInfo> expand(String url) async => PlaylistInfo(
    entries: [
      for (var i = 0; i < entryCount; i++)
        MediaEntry(url: '$url#$i', title: 'Entry $i'),
    ],
  );

  @override
  Future<MediaInfo> probe(String url) async =>
      const MediaInfo(title: 'Single clip', formats: [], id: 'vid1');

  @override
  Stream<DownloadProgress> download(DownloadRequest request) =>
      const Stream.empty();

  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<EngineVersion> version() async =>
      const EngineVersion(ytDlp: '1', ffmpeg: '1');

  @override
  Future<void> update() async {}
}

class _NoopService implements ForegroundService {
  @override
  set onStop(void Function() callback) {}
  @override
  Future<void> start(
    String text, {
    int progress = 0,
    bool indeterminate = true,
  }) async {}
  @override
  Future<void> update(
    String text, {
    int progress = 0,
    bool indeterminate = false,
  }) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<bool> isUnmetered() async => true;
}

class _FakeNetwork implements NetworkMonitor {
  @override
  Stream<void> get onChanged => const Stream.empty();
}

class _FakeStorage extends MediaStorage {
  @override
  Future<Directory> mediaDirectory() async => Directory.systemTemp;
}

Future<void> _waitFor(
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
  ProviderContainer makeContainer(int entryCount) {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return ProviderContainer(
      overrides: [
        downloadEngineProvider.overrideWithValue(_FakeEngine(entryCount)),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
  }

  test(
    'checkSingle routes a multi-entry URL to the selection picker',
    () async {
      final container = makeContainer(3);
      addTearDown(container.dispose);

      final isMulti = await container
          .read(downloaderControllerProvider.notifier)
          .checkSingle('https://example.com/playlist');

      expect(isMulti, isTrue);
      // Sources were handed to the selection controller, all selected.
      final selection = container.read(selectionControllerProvider);
      expect(selection.totalCount, 3);
      expect(selection.selected, hasLength(3));
      // The downloader form is reset (no lingering preview).
      expect(
        container.read(downloaderControllerProvider).phase,
        DownloaderPhase.idle,
      );
    },
  );

  test('checkSingle falls through to probe for a single entry', () async {
    final container = makeContainer(1);
    addTearDown(container.dispose);

    final isMulti = await container
        .read(downloaderControllerProvider.notifier)
        .checkSingle('https://example.com/video');

    expect(isMulti, isFalse);
    final state = container.read(downloaderControllerProvider);
    expect(state.phase, DownloaderPhase.ready);
    expect(state.info?.title, 'Single clip');
  });

  group('enqueue start choice', () {
    late AppDatabase db;

    ProviderContainer wiredContainer() => ProviderContainer(
      overrides: [
        downloadEngineProvider.overrideWithValue(_FakeEngine(1)),
        appDatabaseProvider.overrideWithValue(db),
        foregroundServiceProvider.overrideWithValue(_NoopService()),
        networkMonitorProvider.overrideWithValue(_FakeNetwork()),
        mediaStorageProvider.overrideWithValue(_FakeStorage()),
      ],
    );

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('startNow:false holds the download', () async {
      final container = wiredContainer();
      addTearDown(container.dispose);
      final repo = container.read(queueRepositoryProvider);
      await container.read(queueControllerProvider.future);

      final controller = container.read(downloaderControllerProvider.notifier);
      await controller.probe('https://example.com/video');
      await controller.enqueue(audioOnly: false, startNow: false);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(await repo.countByStatus(TaskStatus.held), 1);
      expect(await repo.countByStatus(TaskStatus.running), 0);
    });

    test('startNow:true starts the download', () async {
      final container = wiredContainer();
      addTearDown(container.dispose);
      final repo = container.read(queueRepositoryProvider);
      await container.read(queueControllerProvider.future);

      final controller = container.read(downloaderControllerProvider.notifier);
      await controller.probe('https://example.com/video');
      await controller.enqueue(audioOnly: false, startNow: true);

      await _waitFor(
        () async => await repo.countByStatus(TaskStatus.running) == 1,
      );
      expect(await repo.countByStatus(TaskStatus.held), 0);
    });

    test('passes a concrete format selector to the request', () async {
      final container = wiredContainer();
      addTearDown(container.dispose);
      await container.read(queueControllerProvider.future);

      final controller = container.read(downloaderControllerProvider.notifier);
      await controller.probe('https://example.com/video');
      await controller.enqueue(
        formatSelector: '137+bestaudio/137',
        audioOnly: false,
        startNow: false,
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect((await _queuedRequest(db)).formatId, '137+bestaudio/137');
    });

    test('probe flags an item already in the library (P9b-4)', () async {
      final container = wiredContainer();
      addTearDown(container.dispose);
      await container.read(queueControllerProvider.future);
      // Seed a saved item whose source id matches the fake probe ('vid1').
      await db
          .into(db.mediaItems)
          .insert(
            MediaItemsCompanion.insert(
              id: 'saved',
              title: 'Saved',
              sourceUrl: 'https://x/v',
              site: 'youtube',
              filePath: '/m/saved',
              type: 'video',
              createdAt: DateTime.utc(2026),
              storageState: 'private',
            ),
          );
      await db
          .into(db.mediaMetadata)
          .insert(
            MediaMetadataCompanion.insert(
              itemId: 'saved',
              sourceId: const Value('vid1'),
            ),
          );

      final controller = container.read(downloaderControllerProvider.notifier);
      await controller.probe('https://example.com/video');

      final state = container.read(downloaderControllerProvider);
      expect(state.existingItem?.id, 'saved');
    });

    test('audio override flows into container + audio quality', () async {
      final container = wiredContainer();
      addTearDown(container.dispose);
      await container.read(queueControllerProvider.future);

      final controller = container.read(downloaderControllerProvider.notifier);
      await controller.probe('https://example.com/video');
      await controller.enqueue(
        audioOnly: true,
        audioFormat: 'mp3',
        audioQuality: '192K',
        startNow: false,
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      final req = await _queuedRequest(db);
      expect(req.audioOnly, isTrue);
      expect(req.container, 'mp3');
      expect(req.audioQuality, '192K');
    });
  });
}

/// Decodes the single queued task's persisted [DownloadRequest].
Future<DownloadRequest> _queuedRequest(AppDatabase db) async {
  final rows = await db.select(db.downloadTasks).get();
  final json = jsonDecode(rows.single.requestJson) as Map<String, dynamic>;
  return DownloadRequest.fromJson(json['request'] as Map<String, dynamic>);
}
