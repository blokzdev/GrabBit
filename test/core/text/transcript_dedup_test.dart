import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/text/transcript_dedup.dart';

void main() {
  group('captionsToTranscript', () {
    test('empty / whitespace-only input yields empty string', () {
      expect(captionsToTranscript(const []), '');
      expect(captionsToTranscript(const ['', '   ', '\n']), '');
    });

    test('joins distinct lines in order', () {
      expect(
        captionsToTranscript(const ['hello world', 'how are you']),
        'hello world how are you',
      );
    });

    test('drops exact consecutive duplicates', () {
      expect(
        captionsToTranscript(const ['hello world', 'hello world']),
        'hello world',
      );
    });

    test('collapses rolling suffix/prefix overlap (auto-caption rollover)', () {
      // Each cue repeats the previous cue's tail then adds new words.
      final out = captionsToTranscript(const [
        'the quick brown',
        'quick brown fox jumps',
        'fox jumps over the lazy',
        'over the lazy dog',
      ]);
      expect(out, 'the quick brown fox jumps over the lazy dog');
    });

    test('a fully-contained line contributes nothing', () {
      expect(
        captionsToTranscript(const ['alpha beta gamma', 'beta gamma']),
        'alpha beta gamma',
      );
    });

    test('splits multi-row cues on newlines', () {
      expect(
        captionsToTranscript(const ['line one\nline two']),
        'line one line two',
      );
    });

    test('normalizes irregular whitespace', () {
      expect(
        captionsToTranscript(const ['  spaced   out \t words ']),
        'spaced out words',
      );
    });

    test('is deterministic', () {
      const lines = ['a b c', 'b c d', 'c d e'];
      expect(captionsToTranscript(lines), captionsToTranscript(lines));
    });
  });
}
