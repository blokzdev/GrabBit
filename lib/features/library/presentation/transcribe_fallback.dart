/// What the manual "Get transcript" action should do once captions (local +
/// online) come up empty (P12e-3). A pure decision so the 3-state on-ramp is
/// unit-testable without the widget. The whisper engine is the last resort;
/// captioned items never reach here.
enum TranscribeFallbackAction {
  /// Transcription is off and can't run here (e.g. non-Android) — keep the
  /// existing "no captions available" dead-end.
  unavailable,

  /// Transcription is off — offer to set it up (download a model + enable).
  offerSetup,

  /// Enabled but no model is downloaded yet — offer the one-time download.
  offerDownload,

  /// Enabled and the model is ready — transcribe now, no prompt.
  transcribeNow,
}

/// Resolves the manual fallback action. [supported] is whether on-device
/// transcription can run at all on this host (Android + engine available);
/// [enabled] is `transcriptionEnabled`; [modelReady] is whether the active
/// model is already downloaded (`engine.ensureReady()`).
TranscribeFallbackAction transcribeFallbackAction({
  required bool supported,
  required bool enabled,
  required bool modelReady,
}) {
  if (!supported) return TranscribeFallbackAction.unavailable;
  if (!enabled) return TranscribeFallbackAction.offerSetup;
  if (!modelReady) return TranscribeFallbackAction.offerDownload;
  return TranscribeFallbackAction.transcribeNow;
}
