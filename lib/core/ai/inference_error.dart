/// Typed inference-engine failure taxonomy (mirrors `graph_error.dart`; see
/// docs/AI-SPEC.md). The embedder is an *enhancement* — callers degrade
/// gracefully on [InferenceErrorCode.unavailable] rather than surfacing a crash.
enum InferenceErrorCode {
  /// The native runtime can't run on this device (e.g. its ABI isn't bundled),
  /// the model isn't downloaded, or the engine isn't ready. AI features degrade
  /// gracefully rather than crash.
  unavailable,
  downloadFailed,
  loadFailed,
  embedFailed,
  generateFailed,
  transcribeFailed,
  ocrFailed,

  /// A capability seam exists but has no working implementation on this build —
  /// e.g. `generateStructured` (P12f forward seam): the method is defined and
  /// gated, but no shipped model implements function-calling yet (v2 Things
  /// Engine; see docs/AI-SPEC.md §2). Distinct from [unavailable] (a device/model
  /// limitation) — this is "not built yet", by design.
  unsupported,
  unknown,
}

class InferenceException implements Exception {
  const InferenceException(this.code, this.message, {this.cause});

  final InferenceErrorCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'InferenceException($code): $message';
}
