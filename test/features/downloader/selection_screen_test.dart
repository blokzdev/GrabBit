import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:grabbit/core/storage/media_storage.dart';
import 'package:grabbit/features/downloader/presentation/selection_controller.dart';
import 'package:grabbit/features/downloader/presentation/selection_screen.dart';

class _FakeEngine implements DownloadEngine {
  @override
  Future<PlaylistInfo> expand(String url) async => const PlaylistInfo(
    isPlaylist: true,
    entries: [
      MediaEntry(url: 'https://y/a', title: 'Clip A'),
      MediaEntry(url: 'https://y/b', title: 'Photo B', isImage: true),
    ],
  );
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
  testWidgets('renders expanded entries with selection actions', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        downloadEngineProvider.overrideWithValue(_FakeEngine()),
        mediaStorageProvider.overrideWithValue(_FakeStorage()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(selectionControllerProvider.notifier)
        .expandUrls('https://y/playlist');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SelectionScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Clip A'), findsOneWidget);
    expect(find.text('Photo B'), findsOneWidget);
    expect(find.text('Download now'), findsOneWidget);
    expect(find.text('Add to queue'), findsOneWidget);
    // Both entries selected by default → "2/2" in the title.
    expect(find.textContaining('2/2'), findsOneWidget);
  });
}
