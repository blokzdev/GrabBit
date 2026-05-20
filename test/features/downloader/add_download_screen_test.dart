import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:grabbit/core/storage/media_storage.dart';
import 'package:grabbit/features/downloader/presentation/add_download_screen.dart';

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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadEngineProvider.overrideWithValue(engine),
          mediaStorageProvider.overrideWithValue(_FakeStorage()),
        ],
        child: const MaterialApp(home: AddDownloadScreen()),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'https://youtu.be/dQw4w9WgXcQ',
    );
    await tester.tap(find.text('Check link'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Never Gonna Give You Up'), findsOneWidget);
    expect(find.text('Best'), findsOneWidget);
    expect(find.text('1080p'), findsOneWidget);
    expect(find.text('Audio only'), findsOneWidget);
  });
}
