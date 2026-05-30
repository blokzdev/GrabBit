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

    test(
      'every model pins a real https litert URL + plausible size (P12d-2)',
      () {
        for (final m in allGenerationModels) {
          expect(m.modelUrl, startsWith('https://huggingface.co/'));
          expect(m.modelUrl, endsWith('.litertlm'));
          expect(m.modelUrl, isNot(isEmpty));
          // Real on-device LLMs are >100 MB.
          expect(m.approxDownloadMb, greaterThan(100));
        }
      },
    );

    test('the flagship is Gemma-4 E2B (Qwen3-4B had no LiteRT build)', () {
      expect(gemma4E2b.modelClass, GenerationModelClass.flagship);
      expect(gemma4E2b.modelTypeId, 'gemma4');
      expect(allGenerationModels, contains(gemma4E2b));
    });
  });
}
