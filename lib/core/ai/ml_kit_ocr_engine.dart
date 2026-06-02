import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/ocr_engine.dart';

/// Android [OcrEngine] backed by ML Kit on-device text recognition (P13b-1).
/// Uses the **bundled Latin-script model** — no Google Play Services, no
/// network, no model download — so it runs offline and fits the sideloaded
/// posture. A recognizer is created per call and closed in `finally` (OCR is
/// on-demand and infrequent, so there's no persistent native handle to leak).
class MlKitOcrEngine implements OcrEngine {
  @override
  bool get isAvailable => true;

  @override
  Future<String> recognizeText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return result.text;
    } on Exception catch (e) {
      throw InferenceException(
        InferenceErrorCode.ocrFailed,
        'Text recognition failed',
        cause: e,
      );
    } finally {
      await recognizer.close();
    }
  }

  @override
  Future<void> close() async {}
}
