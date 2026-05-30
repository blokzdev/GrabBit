import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/generation_model.dart';

void main() {
  group('generationModelById', () {
    test('resolves every shipped id', () {
      for (final m in allGenerationModels) {
        expect(generationModelById(m.id), m);
      }
    });

    test('returns null for an unknown id', () {
      expect(generationModelById('nope'), isNull);
    });
  });

  group('catalog posture + shape', () {
    test('every model is Apache/MIT (off-store redistribution guard)', () {
      for (final m in allGenerationModels) {
        expect(
          m.license.toLowerCase(),
          anyOf(contains('apache'), contains('mit')),
          reason: '${m.id} must be Apache/MIT for off-store distribution',
        );
      }
    });

    test('every model has a display name, blurb, and class', () {
      for (final m in allGenerationModels) {
        expect(m.displayName, isNotEmpty);
        expect(m.blurb, isNotEmpty);
        expect(GenerationModelClass.values, contains(m.modelClass));
        expect(m.approxDownloadMb, greaterThan(0));
        expect(m.maxTokens, greaterThan(0));
      }
    });

    test('exactly one balanced (recommended) model and one flagship', () {
      final balanced = allGenerationModels
          .where((m) => m.modelClass == GenerationModelClass.balanced)
          .toList();
      final flagship = allGenerationModels
          .where((m) => m.modelClass == GenerationModelClass.flagship)
          .toList();
      expect(balanced, hasLength(1));
      expect(flagship, hasLength(1));
    });
  });
}
