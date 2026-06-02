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
}
