/// Pure, engine-free helpers for the on-device abstractive (LLM) summary (P13a).
/// Kept out of the widget so the prompt shape and the on-ramp decision are
/// unit-testable in isolation (mirrors `transcribe_fallback.dart`).
library;

/// System instruction for the summary model — biases toward a brief, faithful
/// summary and discourages invention. On-device; nothing leaves the device.
const String kSummarySystemPrompt =
    'You write brief, faithful summaries. Summarize the content the user '
    'provides in 2–3 plain sentences. Use only information present in the '
    'text; do not add facts, opinions, or preamble.';

/// Builds the (system, user) prompt pair for summarizing [text].
///
/// Small on-device models have a limited context window, so the source is
/// truncated to [maxChars] (head). Full long-transcript chunking is deferred
/// (P13/GraphRAG); for P13a a single head-truncated pass is the floor.
({String systemPrompt, String prompt}) buildSummaryPrompt(
  String text, {
  int maxChars = 4000,
}) {
  final trimmed = text.trim();
  final source = trimmed.length > maxChars
      ? trimmed.substring(0, maxChars).trimRight()
      : trimmed;
  return (
    systemPrompt: kSummarySystemPrompt,
    prompt: 'Summarize the following:\n\n$source',
  );
}

/// What the "Summarize with AI" affordance should do, given the device/feature
/// state. A pure decision so the on-ramp is testable without the widget
/// (mirrors `transcribeFallbackAction`).
enum AiSummaryAction {
  /// No generation model fits this device (low tier) or the runtime can't run
  /// here — show nothing; the extractive TextRank summary stays the floor.
  unavailable,

  /// The device can generate but the user hasn't enabled it — offer to set it
  /// up (deep-link to AI settings to enable + pick a model).
  offerSetup,

  /// Enabled + a model selected, but it isn't downloaded yet — offer the
  /// one-time download (deep-link to AI settings).
  offerDownload,

  /// Enabled and the model is ready — summarize now, inline.
  summarizeNow,
}

/// Resolves the affordance. [eligible] is whether the device tier offers any
/// generation model; [enabled] is `generationEnabled`; [modelReady] is whether
/// the active model is already downloaded (`engine.ensureReady()`).
AiSummaryAction aiSummaryAction({
  required bool eligible,
  required bool enabled,
  required bool modelReady,
}) {
  if (!eligible) return AiSummaryAction.unavailable;
  if (!enabled) return AiSummaryAction.offerSetup;
  if (!modelReady) return AiSummaryAction.offerDownload;
  return AiSummaryAction.summarizeNow;
}
