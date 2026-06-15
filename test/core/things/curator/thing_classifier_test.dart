import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/things/curator/thing_classifier.dart';

void main() {
  group('classify', () {
    test('strong cooking signal → single-tool Recipe', () {
      final c = classify(
        const ClassificationInput(
          title: 'Easy Carbonara Recipe',
          text: 'Add the ingredients, stir the sauce, simmer, and serve.',
        ),
      );
      expect(c.isSingle, isTrue);
      expect(c.candidates.single.type, 'Recipe');
      expect(c.topConfidence, greaterThan(0.3));
    });

    test('host hint alone forces a confident single tool', () {
      final c = classify(
        const ClassificationInput(
          text: 'A nice afternoon out.',
          host: 'www.eventbrite.com',
        ),
      );
      expect(c.isSingle, isTrue);
      expect(c.candidates.single.type, 'Event');
    });

    test('ambiguous signals → narrowed-set of 2–5', () {
      // Mixes recipe + product cues so neither dominates 2×.
      final c = classify(
        const ClassificationInput(
          text: 'recipe ingredient cook — also a great product to buy on sale.',
        ),
      );
      expect(c.isSingle, isFalse);
      expect(c.candidates.length, inInclusiveRange(2, 5));
      final types = c.candidates.map((t) => t.type);
      expect(types, containsAll(['Recipe', 'Product']));
    });

    test('no signal → narrowed-set of all five at floor confidence', () {
      final c = classify(const ClassificationInput(text: 'hello world'));
      expect(c.candidates.length, 5);
      expect(c.confidenceFor('Recipe'), closeTo(0.15, 0.001));
    });

    test('tags contribute to the signal', () {
      final c = classify(
        const ClassificationInput(text: 'A clip.', tags: ['recipe', 'baking']),
      );
      expect(c.candidates.first.type, 'Recipe');
    });

    test('confidence rises with more keyword hits', () {
      final weak = classify(const ClassificationInput(text: 'one recipe'));
      final strong = classify(
        const ClassificationInput(
          text: 'recipe ingredient preheat bake stir simmer serving',
        ),
      );
      expect(
        strong.confidenceFor('Recipe'),
        greaterThan(weak.confidenceFor('Recipe')),
      );
    });
  });
}
