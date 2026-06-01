import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/engine/media_tools_ops.dart';

void main() {
  group('wavForTranscriptionArgs (P12e)', () {
    test('builds 16 kHz mono signed-16-bit PCM WAV args', () {
      final args = wavForTranscriptionArgs(
        input: '/in/clip.mp4',
        output: '/tmp/out.wav',
      );
      expect(args, [
        '-y',
        '-i',
        '/in/clip.mp4',
        '-vn',
        '-ac',
        '1',
        '-ar',
        '16000',
        '-c:a',
        'pcm_s16le',
        '/tmp/out.wav',
      ]);
    });

    test('input precedes output and drops the video stream', () {
      final args = wavForTranscriptionArgs(input: 'a.mkv', output: 'b.wav');
      expect(args.indexOf('a.mkv'), lessThan(args.indexOf('b.wav')));
      expect(args, contains('-vn'));
    });
  });
}
