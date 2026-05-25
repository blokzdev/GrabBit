import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/text/textrank.dart';

void main() {
  group('summarize', () {
    // Five sentences; the "comet" topic recurs across three of them, so a
    // central-sentence ranker should surface comet sentences over the outliers.
    const text =
        'The comet passed close to Earth this week. '
        'Astronomers tracked the comet with several large telescopes. '
        'A local bakery introduced a new sourdough loaf. '
        'The comet will not return for another seventy thousand years. '
        'City traffic was unusually light on Monday morning.';

    test('returns at most maxSentences, verbatim, in original order', () {
      final summary = summarize(text, maxSentences: 2);
      expect(summary.length, lessThanOrEqualTo(2));
      // Every returned sentence is a verbatim sentence from the source.
      final source = text.split(RegExp(r'(?<=[.!?])\s+'));
      for (final s in summary) {
        expect(source, contains(s));
      }
      // Original order preserved: indices are ascending in the source.
      final indices = [for (final s in summary) source.indexOf(s)];
      final sorted = [...indices]..sort();
      expect(indices, sorted);
    });

    test('picks the salient (recurring-topic) sentences', () {
      final summary = summarize(text, maxSentences: 2);
      expect(summary.every((s) => s.toLowerCase().contains('comet')), isTrue);
    });

    test('is deterministic across runs', () {
      expect(summarize(text), summarize(text));
    });

    test('returns [] when at or below minSentences (nothing to condense)', () {
      expect(
        summarize('One sentence here that is long enough. Two here.'),
        isEmpty,
      );
    });

    test('returns [] for empty / whitespace / token-less input', () {
      expect(summarize(''), isEmpty);
      expect(summarize('     \n\t  '), isEmpty);
      expect(
        summarize('1234567890. 0987654321. !!!!!!!. ?????. ......'),
        isEmpty,
      );
    });

    test('does not throw on URLs, punctuation, newlines, or long input', () {
      const messy =
          'Check this out https://example.com/watch?v=abc\n\n'
          'Subscribe!!! And like!!! The video covers rockets and engines. '
          'Rockets use powerful engines to reach orbit. '
          'Engines burn fuel very quickly during launch. '
          'https://sponsor.example.com\n'
          'Thanks for watching the rocket documentary today.';
      expect(() => summarize(messy), returnsNormally);
      final huge = List.filled(
        2000,
        'Rockets fly with engines and fuel.',
      ).join(' ');
      expect(() => summarize(huge), returnsNormally);
    });
  });
}
