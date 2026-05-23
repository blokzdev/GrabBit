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
import 'package:grabbit/features/downloader/presentation/add_download_screen.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/data/settings_repository.dart';

class _FakeEngine implements DownloadEngine {
  _FakeEngine(this.info);
  final MediaInfo info;

  @override
  Future<MediaInfo> probe(String url) async => info;

  @override
  Future<PlaylistInfo> expand(String url) async => PlaylistInfo(
    entries: [MediaEntry(url: url, title: info.title)],
  );

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
  testWidgets('probe shows media info and quality presets', (tester) async {
    final engine = _FakeEngine(
      const MediaInfo(
        title: 'Rick Astley - Never Gonna Give You Up',
        uploader: 'RickAstleyVEVO',
        durationSec: 213,
        site: 'youtube',
        formats: [
          MediaFormat(
            id: '137',
            ext: 'mp4',
            label: '1080p',
            audioOnly: false,
            height: 1080,
          ),
        ],
      ),
    );

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadEngineProvider.overrideWithValue(engine),
          mediaStorageProvider.overrideWithValue(_FakeStorage()),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: AddDownloadScreen()),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'https://youtu.be/dQw4w9WgXcQ',
    );
    await tester.tap(find.text('Check link(s)'));
    await tester.pump(); // expand future
    await tester.pump(); // probe future
    await tester.pump();

    expect(find.textContaining('Never Gonna Give You Up'), findsOneWidget);
    expect(find.text('Best'), findsOneWidget);
    expect(find.text('1080p'), findsOneWidget);
    expect(find.text('Audio only'), findsOneWidget);
    // Preview is a card and shows the formatted duration (213s → 3:33).
    expect(find.byType(Card), findsOneWidget);
    expect(find.text('3:33'), findsOneWidget);
    // Pill actions are present.
    expect(find.widgetWithText(FilledButton, 'Download now'), findsOneWidget);
  });

  testWidgets('offers a paste affordance on the URL field', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadEngineProvider.overrideWithValue(
            _FakeEngine(const MediaInfo(title: 't', formats: [])),
          ),
          mediaStorageProvider.overrideWithValue(_FakeStorage()),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: AddDownloadScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.content_paste), findsOneWidget);
  });

  testWidgets('advanced mode reveals the specific-format picker', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await SettingsRepository(
      db,
    ).write(const SettingsModel(mode: UiMode.advanced));
    final engine = _FakeEngine(
      const MediaInfo(
        title: 'clip',
        formats: [
          MediaFormat(
            id: '137',
            ext: 'mp4',
            label: '1080p',
            audioOnly: false,
            height: 1080,
            vcodec: 'avc1',
            acodec: 'none',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadEngineProvider.overrideWithValue(engine),
          mediaStorageProvider.overrideWithValue(_FakeStorage()),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: AddDownloadScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://x/v');
    await tester.tap(find.text('Check link(s)'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a specific format'), findsOneWidget);
  });
}
