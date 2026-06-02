import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/library/presentation/tag_suggestions.dart';

void main() {
  group('buildTagPrompt (P13c)', () {
    test('wraps the source with the suggest instruction', () {
      final p = buildTagPrompt('A live metal concert.');
      expect(p.systemPrompt, kTagSystemPrompt);
      expect(p.prompt, contains('Suggest tags for the following:'));
      expect(p.prompt, contains('A live metal concert.'));
    });

    test('head-truncates long input to the char budget', () {
      final long = List.filled(5000, 'a').join();
      final p = buildTagPrompt(long, maxChars: 100);
      final slice = p.prompt.split('\n\n').last;
      expect(slice.length, lessThanOrEqualTo(100));
    });
  });

  group('parseTagSuggestions (P13c)', () {
    test('splits commas + newlines, lowercases, strips # and bullets', () {
      expect(parseTagSuggestions('Rock, #Live\n- Concert; metal'), [
        'rock',
        'live',
        'concert',
        'metal',
      ]);
    });

    test('de-duplicates case-insensitively', () {
      expect(parseTagSuggestions('rock, Rock, ROCK'), ['rock']);
    });

    test('excludes already-applied tags (case-insensitive)', () {
      expect(
        parseTagSuggestions('rock, live, jazz', exclude: {'Rock', 'JAZZ'}),
        ['live'],
      );
    });

    test('drops empties and over-long entries, and caps the count', () {
      const raw = 'a,b,c,d,e,f,g,h,i,j';
      expect(parseTagSuggestions(raw, max: 3), ['a', 'b', 'c']);
      expect(parseTagSuggestions('ok, , ${'x' * 40}, fine'), ['ok', 'fine']);
    });

    test('strips surrounding quotes', () {
      expect(parseTagSuggestions('"rock", \'live\''), ['rock', 'live']);
    });
  });

  group('autoTagDecision (P13c-2)', () {
    test('no text → skip', () {
      expect(
        autoTagDecision(hasText: false, modelReady: true),
        AutoTagDecision.skip,
      );
    });
    test('text + model not ready → needs model', () {
      expect(
        autoTagDecision(hasText: true, modelReady: false),
        AutoTagDecision.needsModel,
      );
    });
    test('text + model ready → tag', () {
      expect(
        autoTagDecision(hasText: true, modelReady: true),
        AutoTagDecision.tag,
      );
    });
  });
}
