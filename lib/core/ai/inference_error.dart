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
