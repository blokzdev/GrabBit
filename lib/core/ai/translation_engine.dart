/// On-device **translation** abstraction (P13b-2) — a sibling of the other
/// per-capability AI engines. Translates text between languages fully on-device
/// via ML Kit (no Google Play Services; language models download once over HTTPS
/// and run offline after). Like the others it's capability-gated: a host that
/// can't run it gets the graceful [UnavailableTranslationEngine] no-op (never a
/// crash — AI-SPEC §1). Language codes are BCP-47 (e.g. `en`, `es`).
abstract interface class TranslationEngine {
  /// Whether translation can run on this host (Android + ML Kit).
  bool get isAvailable;

  /// Detects the BCP-47 language of [text]; returns `'und'` when undetermined.
  /// Needs no downloaded model.
  Future<String> identifyLanguage(String text);

  /// Whether the on-device model for the [code] language is downloaded.
  Future<bool> isModelDownloaded(String code);

  /// Downloads the (~30 MB) on-device model for [code]. Throws an
  /// [InferenceException] on failure; a no-op if already present.
  Future<void> downloadModel(String code, {bool requireWifi = true});

  /// Translates [text] from [source] to [target] (BCP-47 codes). Throws an
  /// [InferenceException] (`unavailable`/`translateFailed`) — e.g. when a
  /// required model isn't downloaded or a code isn't supported.
  Future<String> translate(
    String text, {
    required String source,
    required String target,
  });

  /// Releases any native resources held by the engine.
  Future<void> close();
}
