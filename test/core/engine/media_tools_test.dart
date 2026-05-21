import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/engine/media_tools_engine.dart';
import 'package:grabbit/core/engine/media_tools_ops.dart';

void main() {
  group('arg builders', () {
    test('trimArgs input-seeks, copies, and bounds duration', () {
      final args = trimArgs(
        input: '/in.mp4',
        output: '/out.mp4',
        start: const Duration(seconds: 5),
        duration: const Duration(seconds: 10),
      );
      expect(args, [
        '-y',
        '-ss',
        '5.000',
        '-i',
        '/in.mp4',
        '-t',
        '10.000',
        '-c',
        'copy',
        '/out.mp4',
      ]);
    });

    test('frameArgs grabs a single frame at the position', () {
      final args = frameArgs(
        input: '/in.mp4',
        output: '/f.jpg',
        at: const Duration(milliseconds: 2500),
      );
      expect(args, [
        '-y',
        '-ss',
        '2.500',
        '-i',
        '/in.mp4',
        '-frames:v',
        '1',
        '-q:v',
        '2',
        '/f.jpg',
      ]);
    });
  });

  group('toolPercent', () {
    test('maps processed time to a clamped 0..100 percent', () {
      expect(toolPercent(5000, 10000), 50);
      expect(toolPercent(20000, 10000), 100); // clamped
      expect(toolPercent(0, 10000), 0);
    });

    test('is null (indeterminate) without a known total', () {
      expect(toolPercent(5000, null), isNull);
      expect(toolPercent(5000, 0), isNull);
    });
  });
}
