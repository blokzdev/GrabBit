import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/download_error.dart';
import 'package:grabbit/core/engine/error_mapping.dart';
import 'package:grabbit/core/engine/pigeon/engine.pigeon.dart';
import 'package:grabbit/core/engine/pigeon/mappers.dart';

void main() {
  group('FormatDto.toDomain', () {
    test('copies fields straight across', () {
      final f = FormatDto(
        id: '137',
        ext: 'mp4',
        height: 1080,
        tbr: 2500,
        vcodec: 'avc1',
        acodec: 'none',
        audioOnly: false,
        filesize: 1024,
        label: '1080p',
      ).toDomain();

      expect(f, isA<MediaFormat>());
      expect(f.id, '137');
      expect(f.ext, 'mp4');
      expect(f.height, 1080);
      expect(f.tbr, 2500);
      expect(f.audioOnly, isFalse);
      expect(f.filesize, 1024);
      expect(f.label, '1080p');
    });
  });

  group('MediaInfoDto.toDomain', () {
    test('maps nested formats and optional fields', () {
      final info = MediaInfoDto(
        title: 'Clip',
        uploader: 'Chan',
        durationSec: 42,
        thumbnailUrl: 'https://x/y.jpg',
        site: 'youtube',
        formats: [
          FormatDto(id: '140', ext: 'm4a', audioOnly: true, label: 'audio'),
        ],
      ).toDomain();

      expect(info.title, 'Clip');
      expect(info.uploader, 'Chan');
      expect(info.durationSec, 42);
      expect(info.site, 'youtube');
      expect(info.formats, hasLength(1));
      expect(info.formats.single.audioOnly, isTrue);
    });
  });

  group('DownloadRequest.toDto', () {
    test('round-trips all fields', () {
      const req = DownloadRequest(
        taskId: 't1',
        url: 'https://y/v',
        outputDir: '/data/media',
        filenameTemplate: '%(title)s.%(ext)s',
        formatId: '137',
        audioOnly: true,
        container: 'm4a',
        subtitles: true,
        embedThumbnail: true,
        embedMetadata: true,
      );
      final dto = req.toDto();
      expect(dto.taskId, 't1');
      expect(dto.url, 'https://y/v');
      expect(dto.outputDir, '/data/media');
      expect(dto.formatId, '137');
      expect(dto.audioOnly, isTrue);
      expect(dto.container, 'm4a');
      expect(dto.subtitles, isTrue);
    });
  });

  group('ProgressDto.toDomain', () {
    test('maps stages and derives terminal error codes', () {
      DownloadProgress map(String stage, {String? error}) => ProgressDto(
        taskId: 't',
        percent: 50,
        speedBps: 0,
        stage: stage,
        error: error,
      ).toDomain();

      expect(map('downloading').stage, DownloadStage.downloading);
      expect(map('merging').stage, DownloadStage.merging);
      expect(map('done').stage, DownloadStage.done);
      expect(map('done').errorCode, isNull);

      final canceled = map('canceled');
      expect(canceled.stage, DownloadStage.canceled);
      expect(canceled.errorCode, DownloadErrorCode.canceled);

      final errored = map('error', error: 'Unsupported URL: x');
      expect(errored.stage, DownloadStage.error);
      expect(errored.errorCode, DownloadErrorCode.unsupportedSite);

      // Unknown stage strings fall back to error.
      expect(map('weird').stage, DownloadStage.error);
    });
  });

  group('classifyEngineError', () {
    test('maps known yt-dlp messages to codes', () {
      expect(
        classifyEngineError('ERROR: Unsupported URL: https://example.com'),
        DownloadErrorCode.unsupportedSite,
      );
      expect(
        classifyEngineError('Requested format is not available'),
        DownloadErrorCode.formatUnavailable,
      );
      expect(
        classifyEngineError('Unable to download webpage: timed out'),
        DownloadErrorCode.network,
      );
      expect(classifyEngineError(''), DownloadErrorCode.unknown);
      expect(classifyEngineError(null), DownloadErrorCode.unknown);
    });
  });
}
