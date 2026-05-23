import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/utils/shared_url.dart';

void main() {
  group('extractSharedUrl', () {
    test('returns a bare URL unchanged', () {
      expect(
        extractSharedUrl('https://youtu.be/abc123'),
        'https://youtu.be/abc123',
      );
    });

    test('pulls the URL out of surrounding prose', () {
      expect(
        extractSharedUrl('Check this out https://example.com/v/9 via TikTok'),
        'https://example.com/v/9',
      );
    });

    test('trims punctuation that clings to a URL in prose', () {
      expect(
        extractSharedUrl('Watch this (https://example.com/clip).'),
        'https://example.com/clip',
      );
    });

    test('returns null when there is no URL', () {
      expect(extractSharedUrl('no link here'), isNull);
      expect(extractSharedUrl(''), isNull);
    });

    test('strips a tracking param while keeping the path', () {
      expect(
        extractSharedUrl('https://youtu.be/abc123?si=TRACKINGTOKEN'),
        'https://youtu.be/abc123',
      );
    });
  });

  group('stripTrackingParams', () {
    test('keeps meaningful YouTube params and drops trackers', () {
      expect(
        stripTrackingParams(
          'https://www.youtube.com/watch?v=xyz&list=PL1&utm_source=share&si=abc',
        ),
        'https://www.youtube.com/watch?v=xyz&list=PL1',
      );
    });

    test('preserves a timestamp param', () {
      expect(
        stripTrackingParams('https://youtu.be/abc?t=42&si=zzz'),
        'https://youtu.be/abc?t=42',
      );
    });

    test('drops the query entirely when only trackers are present', () {
      expect(
        stripTrackingParams('https://example.com/p?fbclid=123&igshid=456'),
        'https://example.com/p',
      );
    });

    test('returns a URL without a query unchanged', () {
      expect(
        stripTrackingParams('https://example.com/path'),
        'https://example.com/path',
      );
    });

    test('is case-insensitive on tracking param names', () {
      expect(
        stripTrackingParams('https://example.com/p?UTM_SOURCE=x&keep=1'),
        'https://example.com/p?keep=1',
      );
    });
  });
}
