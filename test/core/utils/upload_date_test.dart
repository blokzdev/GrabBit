import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/utils/upload_date.dart';

void main() {
  group('parseUploadDate', () {
    test('parses a valid YYYYMMDD as a UTC date', () {
      expect(parseUploadDate('20240115'), DateTime.utc(2024, 1, 15));
    });

    test('returns null for null or wrong length', () {
      expect(parseUploadDate(null), isNull);
      expect(parseUploadDate('202401'), isNull);
      expect(parseUploadDate('202401151'), isNull);
      expect(parseUploadDate(''), isNull);
    });

    test('returns null for non-numeric input', () {
      expect(parseUploadDate('2024O115'), isNull);
      expect(parseUploadDate('abcdefgh'), isNull);
    });

    test('returns null for out-of-range month or day', () {
      expect(parseUploadDate('20241301'), isNull); // month 13
      expect(parseUploadDate('20240100'), isNull); // day 0
      expect(parseUploadDate('20240132'), isNull); // day 32
    });

    test('returns null for impossible calendar dates (no rollover)', () {
      expect(parseUploadDate('20240230'), isNull); // Feb 30
      expect(parseUploadDate('20230229'), isNull); // not a leap year
    });

    test('accepts a real leap day', () {
      expect(parseUploadDate('20240229'), DateTime.utc(2024, 2, 29));
    });
  });
}
