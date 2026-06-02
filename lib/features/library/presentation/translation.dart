/// Pure, engine-free helper for the on-device translation flow (P13b-2). Kept
/// out of the widget/controller so the decision is unit-testable in isolation
/// (mirrors `aiSummaryAction` / `transcribeFallbackAction`).
library;

/// What the "Translate…" action should do, given the detected source language
/// and the chosen target.
enum TranslateReadiness {
  /// On-device translation can't run here (non-Android).
  unavailable,

  /// The text's language couldn't be determined (`und`).
  notDetected,

  /// The text is already in the target language — nothing to do.
  alreadyInTarget,

  /// Translatable, but the (~30 MB) language model(s) must be downloaded first.
  needsDownload,

  /// Ready to translate now (models present).
  ready,
}

/// [source] is the detected BCP-47 code (or `'und'`); [target] the chosen code;
/// [modelsDownloaded] whether the required model(s) are already on device.
TranslateReadiness translateReadiness({
  required bool engineAvailable,
  required String source,
  required String target,
  required bool modelsDownloaded,
}) {
  if (!engineAvailable) return TranslateReadiness.unavailable;
  if (source.isEmpty || source == 'und') return TranslateReadiness.notDetected;
  if (source == target) return TranslateReadiness.alreadyInTarget;
  return modelsDownloaded
      ? TranslateReadiness.ready
      : TranslateReadiness.needsDownload;
}
