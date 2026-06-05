import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/library/presentation/translation.dart';

void main() {
  group('translateReadiness (P13b-2)', () {
    test('engine unavailable → unavailable', () {
      expect(
        translateReadiness(
          engineAvailable: false,
          source: 'es',
          target: 'en',
          modelsDownloaded: true,
        ),
        TranslateReadiness.unavailable,
      );
    });

    test('undetermined source → notDetected', () {
      for (final s in ['und', '']) {
        expect(
          translateReadiness(
            engineAvailable: true,
            source: s,
            target: 'en',
            modelsDownloaded: true,
          ),
          TranslateReadiness.notDetected,
        );
      }
    });

    test('source equals target → alreadyInTarget', () {
      expect(
        translateReadiness(
          engineAvailable: true,
          source: 'en',
          target: 'en',
          modelsDownloaded: true,
        ),
        TranslateReadiness.alreadyInTarget,
      );
    });

    test('translatable but models missing → needsDownload', () {
      expect(
        translateReadiness(
          engineAvailable: true,
          source: 'es',
          target: 'en',
          modelsDownloaded: false,
        ),
        TranslateReadiness.needsDownload,
      );
    });

    test('translatable with models present → ready', () {
      expect(
        translateReadiness(
          engineAvailable: true,
          source: 'es',
          target: 'en',
          modelsDownloaded: true,
        ),
        TranslateReadiness.ready,
      );
    });
  });

  group('translationLanguageName (P13f-2)', () {
    test('returns the friendly name for a supported code', () {
      expect(translationLanguageName('es'), 'Spanish');
      expect(translationLanguageName('ja'), 'Japanese');
      expect(translationLanguageName('zh'), 'Chinese');
    });

    test('falls back to the upper-cased code for an unknown one', () {
      expect(translationLanguageName('xx'), 'XX');
    });

    test('every supported language has a non-empty unique code', () {
      final codes = kTranslationLanguages.map((l) => l.code).toList();
      expect(codes.toSet().length, codes.length);
      expect(codes.every((c) => c.isNotEmpty), isTrue);
    });
  });
}
