import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:grabbit/core/storage/media_storage.dart';
import 'package:grabbit/features/downloader/presentation/selection_controller.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';

class _FakeEngine implements DownloadEngine {
  _FakeEngine(this.entries);
  final List<MediaEntry> entries;

  @override
  Future<PlaylistInfo> expand(String url) async =>
      PlaylistInfo(entries: entries, isPlaylist: entries.length > 1);

  @override
  Future<MediaInfo> probe(String url) async =>
      const MediaInfo(title: '', formats: []);
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

class _FakeStorage extends MediaStorage {
  @override
  Future<Directory> mediaDirectory() async => Directory.systemTemp;
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        downloadEngineProvider.overrideWithValue(
          _FakeEngine([
            const MediaEntry(url: 'https://y/a', title: 'A'),
            const MediaEntry(url: 'https://y/b', title: 'B'),
            const MediaEntry(url: 'https://y/c', title: 'C'),
          ]),
        ),
        mediaStorageProvider.overrideWithValue(_FakeStorage()),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('expandUrls populates entries and selects all', () async {
    final c = container.read(selectionControllerProvider.notifier);
    await c.expandUrls('https://y/playlist');
    final state = container.read(selectionControllerProvider);
    expect(state.totalCount, 3);
    expect(state.selected.length, 3);
  });

  test('toggle + addToBatch holds only the selected entries', () async {
    final c = container.read(selectionControllerProvider.notifier);
    await c.expandUrls('https://y/playlist');
    c.toggle('https://y/b'); // deselect B
    expect(container.read(selectionControllerProvider).selected.length, 2);

    await c.addToBatch();
    final repo = QueueRepository(db);
    expect(await repo.countByStatus(TaskStatus.held), 2);
    expect(await repo.countByStatus(TaskStatus.queued), 0);
  });

  test('selectNone clears the selection', () async {
    final c = container.read(selectionControllerProvider.notifier);
    await c.expandUrls('https://y/playlist');
    c.selectNone();
    expect(container.read(selectionControllerProvider).selected, isEmpty);
  });
}
