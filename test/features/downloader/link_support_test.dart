import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/downloader/presentation/link_support.dart';

void main() {
  test('TikTok photo post → specific notice, no update suggestion', () {
    final info = describeUnsupportedLink(
      'https://vt.tiktok.com/ZSxu1JB36/',
      rawError:
          'ERROR: Unsupported URL: '
          'https://www.tiktok.com/@thedailyoptimist/photo/76377255917?_r=1',
    );
    expect(info.message.toLowerCase(), contains('photo'));
    expect(info.offerUpdate, isFalse);
  });

  test('prefers the resolved URL in rawError over the pasted short link', () {
    // The pasted host maps to TikTok, but the /photo/ path is only present in
    // the engine-resolved URL inside rawError.
    final info = describeUnsupportedLink(
      'https://vt.tiktok.com/abc/',
      rawError: 'Unsupported URL: https://www.tiktok.com/@u/photo/1',
    );
    expect(info.message.toLowerCase(), contains('photo'));
  });

  test('known platform, unrecognized URL form → no update suggestion', () {
    final info = describeUnsupportedLink('https://www.instagram.com/explore/');
    expect(info.message, contains('Instagram'));
    expect(info.offerUpdate, isFalse);
  });

  test('unknown site → soft "update may add it" hint', () {
    final info = describeUnsupportedLink('https://example.com/video/123');
    expect(info.offerUpdate, isTrue);
    expect(info.message.toLowerCase(), contains('site'));
  });

  test('malformed input is handled safely (treated as unknown)', () {
    final info = describeUnsupportedLink('not a url');
    expect(info.offerUpdate, isTrue);
  });
}
