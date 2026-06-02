import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/ocr_engine_factory.dart';
import 'package:grabbit/core/ai/unavailable_ocr_engine.dart';

void main() {
  group('OCR engine (P13b-1)', () {
    test('factory returns the graceful no-op off Android (the test host)', () {
      // ocrEngineFor() picks the platform engine; on the CI/test host (not
      // Android) that's the UnavailableOcrEngine.
      final engine = ocrEngineFor();
      expect(engine.isAvailable, isFalse);
    });

    test(
      'UnavailableOcrEngine reports unavailable and throws on use',
      () async {
        const engine = UnavailableOcrEngine();
        expect(engine.isAvailable, isFalse);
        expect(
          () => engine.recognizeText('/some/image.jpg'),
          throwsA(
            isA<InferenceException>().having(
              (e) => e.code,
              'code',
              InferenceErrorCode.unavailable,
            ),
          ),
        );
        await engine.close(); // no-op, must not throw
      },
    );
  });
}
