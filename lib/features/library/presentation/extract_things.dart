/// Pure, engine-free helper for the on-demand "Extract Things" affordance (P15c).
/// Kept out of the widget so the on-ramp decision is unit-testable in isolation
/// (mirrors `aiSummaryAction` in `ai_summary.dart`).
library;

/// What the "Extract Things" action should do, given the device/feature state.
/// A pure decision so the on-ramp is testable without the widget.
enum ExtractThingsAction {
  /// No function-calling-capable model is in play — either the device tier can't
  /// run structured extraction, or the active generation model isn't FC-capable
  /// (e.g. SmolLM2). The handler explains which, and routes to AI settings when
  /// it's a fixable model selection.
  unavailable,

  /// The device can extract but generation isn't enabled — offer to set it up
  /// (deep-link to AI settings to enable + pick a model).
  offerSetup,

  /// Enabled + an FC-capable model selected, but it isn't downloaded yet — offer
  /// the one-time download (deep-link to AI settings).
  offerDownload,

  /// Enabled and the model is ready — extract now.
  extractNow,
}

/// Resolves the affordance. [eligible] is whether an FC-capable model is the
/// active one (`activeStructuredExtractionModel != null`); [enabled] is
/// `generationEnabled`; [modelReady] is whether the active model is already
/// downloaded (`engine.ensureReady()` — no fetch).
ExtractThingsAction extractThingsAction({
  required bool eligible,
  required bool enabled,
  required bool modelReady,
}) {
  if (!eligible) return ExtractThingsAction.unavailable;
  if (!enabled) return ExtractThingsAction.offerSetup;
  if (!modelReady) return ExtractThingsAction.offerDownload;
  return ExtractThingsAction.extractNow;
}
