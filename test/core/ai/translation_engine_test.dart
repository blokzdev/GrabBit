import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/ml_kit_translation_engine.dart';
import 'package:grabbit/core/ai/translation_engine_factory.dart';
import 'package:grabbit/core/ai/unavailable_translation_engine.dart';

void main() {
  group('translateLanguageForCode (P13b-2)', () {
    test('maps a supported BCP code to the ML Kit language', () {
      expect(translateLanguageForCode('es'), TranslateLanguage.spanish);
      expect(translateLanguageForCode('EN'), TranslateLanguage.english);
    });

    test('returns null for an unsupported code', () {
      expect(translateLanguageForCode('xx'), isNull);
      expect(translateLanguageForCode('und'), isNull);
    });
  });

  group('translation engine availability (P13b-2)', () {
    test('factory returns the graceful no-op off Android (the test host)', () {
      expect(translationEngineFor().isAvailable, isFalse);
    });

    test('UnavailableTranslationEngine degrades gracefully', () async {
      const engine = UnavailableTranslationEngine();
      expect(engine.isAvailable, isFalse);
      expect(await engine.identifyLanguage('hola'), 'und');
      expect(await engine.isModelDownloaded('es'), isFalse);
      expect(
        () => engine.translate('hola', source: 'es', target: 'en'),
        throwsA(
          isA<InferenceException>().having(
            (e) => e.code,
            'code',
            InferenceErrorCode.unavailable,
          ),
        ),
      );
      expect(
        () => engine.downloadModel('es'),
        throwsA(isA<InferenceException>()),
      );
      await engine.close();
    });
  });
}
