import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/ocr_engine.dart';

/// Graceful no-op [OcrEngine] for hosts that can't run ML Kit text recognition
/// (non-Android until P15, CI). Never crashes — OCR simply stays unavailable
/// (AI-SPEC §1); the "Scan text" affordance is hidden when `isAvailable` is
/// false.
class UnavailableOcrEngine implements OcrEngine {
  const UnavailableOcrEngine();

  static const _ex = InferenceException(
    InferenceErrorCode.unavailable,
    'On-device text recognition is not available on this device',
  );

  @override
  bool get isAvailable => false;

  @override
  Future<String> recognizeText(String imagePath) => throw _ex;

  @override
  Future<void> close() async {}
}
