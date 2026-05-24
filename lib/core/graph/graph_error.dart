/// Typed graph-store failure taxonomy (see docs/GRAPH-SPEC.md §8).
enum GraphErrorCode {
  /// The native engine can't run on this device (e.g. its ABI isn't bundled) or
  /// the store isn't open. Graph features degrade gracefully rather than crash.
  unavailable,
  openFailed,
  queryFailed,
  unknown,
}

class GraphException implements Exception {
  const GraphException(this.code, this.message, {this.cause});

  final GraphErrorCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'GraphException($code): $message';
}
