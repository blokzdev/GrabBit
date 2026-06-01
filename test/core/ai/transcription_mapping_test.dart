import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/transcription_mapping.dart';
import 'package:grabbit/core/text/transcript_dedup.dart';

void main() {
  group('transcriptResultFromSegments', () {
    test('builds flat text + timed cues from whisper segments', () {
      final result = transcriptResultFromSegments([
        (start: const Duration(milliseconds: 0), text: 'Hello there'),
        (start: const Duration(milliseconds: 1500), text: 'general world'),
      ]);
      expect(result.flat, 'Hello there general world');

      final cues = decodeCues(result.cuesJson);
      expect(cues, hasLength(2));
      expect(cues.first.start, Duration.zero);
      expect(cues.first.text, 'Hello there');
      expect(cues[1].start, const Duration(milliseconds: 1500));
    });

    test('drops blank / whitespace-only segments', () {
      final result = transcriptResultFromSegments([
        (start: const Duration(milliseconds: 0), text: '   '),
        (start: const Duration(milliseconds: 500), text: 'real speech'),
        (start: const Duration(milliseconds: 900), text: ''),
      ]);
      expect(result.flat, 'real speech');
      expect(decodeCues(result.cuesJson), hasLength(1));
    });

    test('trims surrounding whitespace on each segment', () {
      final result = transcriptResultFromSegments([
        (start: Duration.zero, text: '  padded  '),
      ]);
      expect(result.flat, 'padded');
    });

    test('de-duplicates overlapping rolling segments like captions do', () {
      // Whisper rarely overlaps, but the shared dedup must collapse it if it does.
      final result = transcriptResultFromSegments([
        (start: const Duration(milliseconds: 0), text: 'a b c'),
        (start: const Duration(milliseconds: 1000), text: 'b c d'),
      ]);
      expect(result.flat, 'a b c d');
    });

    test('empty input yields an empty result', () {
      final result = transcriptResultFromSegments(const []);
      expect(result.flat, '');
      expect(decodeCues(result.cuesJson), isEmpty);
    });

    test('output shape matches the caption path (flat == joined cue text)', () {
      final result = transcriptResultFromSegments([
        (start: Duration.zero, text: 'one'),
        (start: const Duration(seconds: 1), text: 'two'),
      ]);
      final cues = decodeCues(result.cuesJson);
      expect(cues.map((c) => c.text).join(' '), result.flat);
    });
  });
}
