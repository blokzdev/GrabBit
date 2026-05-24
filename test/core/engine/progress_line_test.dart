import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/engine/progress_line.dart';

void main() {
  test('parses speed and total from a typical download line', () {
    final r = parseProgressLine(
      '[download]  45.2% of  100.00MiB at  1.50MiB/s ETA 00:33',
    );
    expect(r.speedBps, closeTo(1.5 * 1024 * 1024, 1));
    expect(r.totalBytes, 100 * 1024 * 1024);
  });

  test('handles ~estimate, KiB, and GiB units', () {
    expect(
      parseProgressLine('[download] 10% of ~2.00GiB at 500.00KiB/s').totalBytes,
      2 * 1024 * 1024 * 1024,
    );
    expect(
      parseProgressLine('at 500.00KiB/s').speedBps,
      closeTo(500 * 1024, 1),
    );
  });

  test('returns nulls for Unknown / unparseable / empty lines', () {
    final u = parseProgressLine('[download]  0.0% of Unknown at Unknown B/s');
    expect(u.speedBps, isNull);
    expect(u.totalBytes, isNull);
    expect(parseProgressLine(null).speedBps, isNull);
    expect(parseProgressLine('[Merger] Merging formats').totalBytes, isNull);
  });
}
