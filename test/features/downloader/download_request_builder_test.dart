import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/features/downloader/data/download_request_builder.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';

void main() {
  group('buildDownloadRequest', () {
    test('defaults preserve current behavior (no power options)', () {
      const settings = SettingsModel();
      final req = buildDownloadRequest(
        taskId: 't1',
        url: 'https://y/v',
        outputDir: '/media',
        settings: settings,
        audioOnly: false,
        formatSelector: 'best',
      );
      expect(req.container, 'mp4'); // defaultContainer
      expect(req.rateLimit, isNull);
      expect(req.concurrentFragments, isNull); // 1 ⇒ omitted
      expect(req.audioQuality, isNull);
      expect(req.downloadArchivePath, isNull);
      expect(req.extraArgs, isNull);
    });

    test('audio path uses audioFormat as the container/codec', () {
      const settings = SettingsModel(audioFormat: 'mp3', audioQuality: '192K');
      final req = buildDownloadRequest(
        taskId: 't1',
        url: 'https://y/v',
        outputDir: '/media',
        settings: settings,
        audioOnly: true,
      );
      expect(req.container, 'mp3');
      expect(req.audioQuality, '192K');
    });

    test('audioQuality is omitted for video and when set to best', () {
      const audioBest = SettingsModel(audioQuality: 'best');
      expect(
        buildDownloadRequest(
          taskId: 't',
          url: 'u',
          outputDir: '/m',
          settings: audioBest,
          audioOnly: true,
        ).audioQuality,
        isNull,
      );
      const audio192 = SettingsModel(audioQuality: '192K');
      expect(
        buildDownloadRequest(
          taskId: 't',
          url: 'u',
          outputDir: '/m',
          settings: audio192,
          audioOnly: false, // video ⇒ no audio quality
        ).audioQuality,
        isNull,
      );
    });

    test('power options flow into the request', () {
      const settings = SettingsModel(
        rateLimit: '1M',
        concurrentFragments: 4,
        useDownloadArchive: true,
        extraDownloadArgs: '--no-mtime --retries 3',
        defaultContainer: 'mkv',
      );
      final req = buildDownloadRequest(
        taskId: 't1',
        url: 'https://y/v',
        outputDir: '/media',
        settings: settings,
        audioOnly: false,
        formatSelector: 'best',
      );
      expect(req.rateLimit, '1M');
      expect(req.concurrentFragments, 4);
      expect(req.container, 'mkv');
      expect(req.downloadArchivePath, '/media/.download-archive.txt');
      expect(req.extraArgs, ['--no-mtime', '--retries', '3']);
    });

    test('persists losslessly through toJson/fromJson', () {
      const settings = SettingsModel(
        rateLimit: '2M',
        concurrentFragments: 8,
        useDownloadArchive: true,
        extraDownloadArgs: '--write-subs',
      );
      final req = buildDownloadRequest(
        taskId: 't1',
        url: 'https://y/v',
        outputDir: '/media',
        settings: settings,
        audioOnly: false,
      );
      final restored = DownloadRequest.fromJson(req.toJson());
      expect(restored.rateLimit, '2M');
      expect(restored.concurrentFragments, 8);
      expect(restored.downloadArchivePath, '/media/.download-archive.txt');
      expect(restored.extraArgs, ['--write-subs']);
    });
  });

  group('parseExtraArgs', () {
    test('splits on whitespace and drops empties', () {
      expect(parseExtraArgs('  --no-mtime   --retries 3 '), [
        '--no-mtime',
        '--retries',
        '3',
      ]);
    });

    test('returns an empty list for blank input', () {
      expect(parseExtraArgs(''), isEmpty);
      expect(parseExtraArgs('   '), isEmpty);
    });
  });
}
