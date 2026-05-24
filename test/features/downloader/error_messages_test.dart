import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/engine/download_error.dart';
import 'package:grabbit/features/downloader/presentation/error_messages.dart';

void main() {
  test('suggestsEngineUpdate only for a site-changed extractor failure', () {
    // A genuinely unsupported link is handled via describeUnsupportedLink, not
    // an update prompt (updating rarely helps and shouldn't be implied).
    expect(suggestsEngineUpdate(DownloadErrorCode.extractorFailed), isTrue);
    expect(suggestsEngineUpdate(DownloadErrorCode.unsupportedSite), isFalse);
    expect(suggestsEngineUpdate(DownloadErrorCode.network), isFalse);
    expect(suggestsEngineUpdate(null), isFalse);
  });

  test('friendlyError maps known codes and falls back otherwise', () {
    expect(
      friendlyError(DownloadErrorCode.network, 'raw'),
      contains('Network'),
    );
    expect(
      friendlyError(DownloadErrorCode.unknown, 'raw message'),
      'raw message',
    );
    expect(friendlyError(null, 'raw message'), 'raw message');
  });
}
