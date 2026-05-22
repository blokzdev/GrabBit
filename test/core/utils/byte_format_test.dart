import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/utils/byte_format.dart';

void main() {
  test('returns empty for null or negative', () {
    expect(formatBytes(null), '');
    expect(formatBytes(-1), '');
  });

  test('bytes under 1 KB', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(512), '512 B');
  });

  test('KB rounded whole', () {
    expect(formatBytes(1024), '1 KB');
    expect(formatBytes(1536), '2 KB');
  });

  test('MB and GB with one decimal', () {
    expect(formatBytes(1024 * 1024), '1.0 MB');
    expect(formatBytes((12.3 * 1024 * 1024).round()), '12.3 MB');
    expect(formatBytes(1024 * 1024 * 1024), '1.0 GB');
  });
}
