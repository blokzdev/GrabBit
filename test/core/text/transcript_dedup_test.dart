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

  group('captionsToTimedTranscript (P10f-4)', () {
    TranscriptCue cue(int ms, String text) => TranscriptCue(
      start: Duration(milliseconds: ms),
      text: text,
    );

    test('keeps each line start time and strips rolling overlap', () {
      final out = captionsToTimedTranscript([
        cue(0, 'the quick brown'),
        cue(1000, 'quick brown fox jumps'),
        cue(2000, 'fox jumps over the lazy'),
        cue(3000, 'over the lazy dog'),
      ]);
      expect(out.map((c) => c.text).toList(), [
        'the quick brown',
        'fox jumps',
        'over the lazy',
        'dog',
      ]);
      expect(out.map((c) => c.start.inMilliseconds).toList(), [
        0,
        1000,
        2000,
        3000,
      ]);
    });

    test('drops cues that add nothing new (no empty lines)', () {
      final out = captionsToTimedTranscript([
        cue(0, 'alpha beta gamma'),
        cue(1000, 'beta gamma'), // fully contained ⇒ dropped
        cue(2000, 'delta'),
      ]);
      expect(out.map((c) => c.text).toList(), ['alpha beta gamma', 'delta']);
      expect(out.map((c) => c.start.inMilliseconds).toList(), [0, 2000]);
    });

    test('flat transcript equals the joined timed lines', () {
      const lines = ['a b c', 'b c d', 'c d e'];
      final timed = captionsToTimedTranscript([
        for (final l in lines) TranscriptCue(start: Duration.zero, text: l),
      ]);
      expect(captionsToTranscript(lines), timed.map((c) => c.text).join(' '));
    });

    test('cues round-trip through encode/decode', () {
      final cues = [cue(0, 'hello world'), cue(1500, 'second line')];
      final restored = decodeCues(encodeCues(cues));
      expect(restored.map((c) => c.start.inMilliseconds).toList(), [0, 1500]);
      expect(restored.map((c) => c.text).toList(), [
        'hello world',
        'second line',
      ]);
      expect(decodeCues(''), isEmpty);
    });
  });
}
