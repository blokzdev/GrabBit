/// On-device **text recognition (OCR)** abstraction (P13b-1) — a sibling of the
/// other per-capability AI engines. Extracts text from an image file fully
/// on-device; unlike the model-based engines there's no download or device-tier
/// gating (the bundled Latin model needs no Google Play Services and runs
/// offline). Implementations are capability-gated: a host that can't run it gets
/// the graceful [UnavailableOcrEngine] no-op (never a crash — AI-SPEC §1).
abstract interface class OcrEngine {
  /// Whether text recognition can run on this host (Android + bundled model).
  bool get isAvailable;

  /// Recognizes text in the image at [imagePath] and returns the extracted text
  /// (possibly empty — no readable text). Throws an [InferenceException]
  /// (`unavailable`/`ocrFailed`) on failure.
  Future<String> recognizeText(String imagePath);

  /// Releases any native resources held by the recognizer.
  Future<void> close();
}
