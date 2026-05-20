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
