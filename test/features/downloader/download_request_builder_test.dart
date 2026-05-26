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

  group('subtitles / SponsorBlock / chapters', () {
    test('subtitle langs parse from CSV; off when empty', () {
      final on = buildDownloadRequest(
        taskId: 't',
        url: 'u',
        outputDir: '/m',
        settings: const SettingsModel(
          subtitleLangs: 'en, es',
          subtitleAuto: true,
          subtitleFormat: 'vtt',
        ),
        audioOnly: false,
      );
      expect(on.subtitleLangs, ['en', 'es']);
      expect(on.autoSubs, isTrue);
      expect(on.subtitleFormat, 'vtt');

      final off = buildDownloadRequest(
        taskId: 't',
        url: 'u',
        outputDir: '/m',
        settings: const SettingsModel(),
        audioOnly: false,
      );
      expect(off.subtitleLangs, isNull);
    });

    test('SponsorBlock only populated when mode != off', () {
      final off = buildDownloadRequest(
        taskId: 't',
        url: 'u',
        outputDir: '/m',
        settings: const SettingsModel(sponsorBlockCategories: 'sponsor'),
        audioOnly: false,
      );
      expect(off.sponsorBlock, isNull);
      expect(off.sponsorBlockCategories, isNull);

      final on = buildDownloadRequest(
        taskId: 't',
        url: 'u',
        outputDir: '/m',
        settings: const SettingsModel(
          sponsorBlockMode: 'remove',
          sponsorBlockCategories: 'sponsor,selfpromo',
        ),
        audioOnly: false,
      );
      expect(on.sponsorBlock, 'remove');
      expect(on.sponsorBlockCategories, ['sponsor', 'selfpromo']);
    });

    test('chapter flags pass through', () {
      final req = buildDownloadRequest(
        taskId: 't',
        url: 'u',
        outputDir: '/m',
        settings: const SettingsModel(embedChapters: true, splitChapters: true),
        audioOnly: false,
      );
      expect(req.embedChapters, isTrue);
      expect(req.splitChapters, isTrue);
    });
  });

  group('buildCaptionFetchRequest (P10f-2)', () {
    test('builds a subtitles-only request targeting the item folder', () {
      final req = buildCaptionFetchRequest(
        sourceUrl: 'https://y/v',
        mediaPath: '/media/task42/My Clip.mp4',
        settings: const SettingsModel(subtitleFormat: 'vtt'),
        lang: 'es',
      );
      expect(req.skipDownload, isTrue);
      expect(req.subtitleLangs, ['es']);
      expect(req.autoSubs, isTrue);
      expect(req.subtitleFormat, 'vtt');
      expect(req.url, 'https://y/v');
      // outputDir/taskId reconstruct the existing media folder so the caption
      // sidecar lands beside the media.
      expect('${req.outputDir}/${req.taskId}', '/media/task42');
      expect(req.filenameTemplate, 'My Clip.%(ext)s');
    });

    test(
      'skipDownload round-trips through toJson/fromJson (default false)',
      () {
        final req = buildCaptionFetchRequest(
          sourceUrl: 'u',
          mediaPath: '/m/t/f.mp4',
          settings: const SettingsModel(),
          lang: 'en',
        );
        expect(DownloadRequest.fromJson(req.toJson()).skipDownload, isTrue);
        // Absent in JSON ⇒ defaults to false (backward-compatible).
        final legacy = DownloadRequest.fromJson(const {
          'taskId': 't',
          'url': 'u',
          'outputDir': '/m',
          'filenameTemplate': '%(title)s.%(ext)s',
        });
        expect(legacy.skipDownload, isFalse);
      },
    );
  });

  group('auto-download captions (P10f-3)', () {
    DownloadRequest build(SettingsModel s) => buildDownloadRequest(
      taskId: 't',
      url: 'u',
      outputDir: '/m',
      settings: s,
      audioOnly: false,
    );

    test(
      'on + no explicit langs ⇒ fetches the in-app language + auto-subs',
      () {
        final req = build(const SettingsModel(autoDownloadCaptions: true));
        expect(req.subtitleLangs, ['en']); // default locale ⇒ en
        expect(req.autoSubs, isTrue);

        final es = build(
          const SettingsModel(autoDownloadCaptions: true, locale: 'es-ES'),
        );
        expect(es.subtitleLangs, ['es']);
      },
    );

    test('explicit subtitle langs win over the setting', () {
      final req = build(
        const SettingsModel(
          autoDownloadCaptions: true,
          subtitleLangs: 'fr,de',
          subtitleAuto: false,
        ),
      );
      expect(req.subtitleLangs, ['fr', 'de']);
      expect(req.autoSubs, isFalse); // not overridden
    });

    test('off ⇒ unchanged (no captions injected)', () {
      final req = build(const SettingsModel());
      expect(req.subtitleLangs, isNull);
      expect(req.autoSubs, isFalse);
    });
  });

  group('SettingsModel.captionLanguage', () {
    String lang(String? locale) =>
        SettingsModel(locale: locale).captionLanguage;
    test('falls back to en; strips region', () {
      expect(lang(null), 'en');
      expect(lang('es'), 'es');
      expect(lang('en-US'), 'en');
      expect(lang('pt_BR'), 'pt');
    });
  });

  group('parseCsvList', () {
    test('splits on commas and whitespace, drops empties', () {
      expect(parseCsvList('en, es ,  en-US'), ['en', 'es', 'en-US']);
      expect(parseCsvList(''), isEmpty);
    });
  });

  group('formatSelectorFor', () {
    MediaFormat fmt({String? vcodec, String? acodec}) => MediaFormat(
      id: '137',
      ext: 'mp4',
      label: 'x',
      audioOnly: vcodec == null && acodec != null,
      vcodec: vcodec,
      acodec: acodec,
    );

    test('video-only merges +bestaudio with a fallback', () {
      final r = formatSelectorFor(fmt(vcodec: 'avc1', acodec: 'none'));
      expect(r.selector, '137+bestaudio/137');
      expect(r.audioOnly, isFalse);
    });

    test('audio-only is flagged audioOnly', () {
      final r = formatSelectorFor(fmt(vcodec: 'none', acodec: 'mp4a'));
      expect(r.selector, '137');
      expect(r.audioOnly, isTrue);
    });

    test('progressive (video + audio) is used as-is', () {
      final r = formatSelectorFor(fmt(vcodec: 'avc1', acodec: 'mp4a'));
      expect(r.selector, '137');
      expect(r.audioOnly, isFalse);
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
