import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/utils/duration_format.dart';

void main() {
  test('returns empty for null or negative', () {
    expect(formatDuration(null), '');
    expect(formatDuration(-5), '');
  });

  test('formats seconds under a minute', () {
    expect(formatDuration(0), '0:00');
    expect(formatDuration(9), '0:09');
    expect(formatDuration(59), '0:59');
  });

  test('formats minutes and seconds', () {
    expect(formatDuration(213), '3:33');
    expect(formatDuration(600), '10:00');
  });

  test('formats hours as H:MM:SS', () {
    expect(formatDuration(3600), '1:00:00');
    expect(formatDuration(3661), '1:01:01');
    expect(formatDuration(7325), '2:02:05');
  });
}
