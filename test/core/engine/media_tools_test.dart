import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/engine/media_tools_engine.dart';
import 'package:grabbit/core/engine/media_tools_ops.dart';

void main() {
  group('arg builders', () {
    test('burnInSubtitlesArgs re-encodes with a quoted subtitles filter', () {
      expect(
        burnInSubtitlesArgs(
          input: '/in.mp4',
          output: '/out.mp4',
          subtitlePath: '/subs/clip.en.srt',
        ),
        [
          '-y',
          '-i',
          '/in.mp4',
          '-vf',
          "subtitles='/subs/clip.en.srt'",
          '/out.mp4',
        ],
      );
    });

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

  group('transform builders', () {
    test('rotate uses transpose 1 (cw) / 2 (ccw)', () {
      expect(rotateArgs(input: '/i.mp4', output: '/o.mp4', clockwise: true), [
        '-y',
        '-i',
        '/i.mp4',
        '-vf',
        'transpose=1',
        '/o.mp4',
      ]);
      expect(rotateArgs(input: '/i.mp4', output: '/o.mp4', clockwise: false), [
        '-y',
        '-i',
        '/i.mp4',
        '-vf',
        'transpose=2',
        '/o.mp4',
      ]);
    });

    test('flip maps vertical→vflip, mirror→hflip', () {
      expect(flipArgs(input: '/i.mp4', output: '/o.mp4', vertical: true), [
        '-y',
        '-i',
        '/i.mp4',
        '-vf',
        'vflip',
        '/o.mp4',
      ]);
      expect(flipArgs(input: '/i.mp4', output: '/o.mp4', vertical: false), [
        '-y',
        '-i',
        '/i.mp4',
        '-vf',
        'hflip',
        '/o.mp4',
      ]);
    });

    test('reverse reverses both streams', () {
      expect(reverseArgs(input: '/i.mp4', output: '/o.mp4'), [
        '-y',
        '-i',
        '/i.mp4',
        '-vf',
        'reverse',
        '-af',
        'areverse',
        '/o.mp4',
      ]);
    });

    test('extract audio strips video; convert is filter-free', () {
      expect(extractAudioArgs(input: '/i.mp4', output: '/o.m4a'), [
        '-y',
        '-i',
        '/i.mp4',
        '-vn',
        '/o.m4a',
      ]);
      expect(convertArgs(input: '/i.png', output: '/o.jpg'), [
        '-y',
        '-i',
        '/i.png',
        '/o.jpg',
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
