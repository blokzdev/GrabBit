/// Platform-agnostic on-device graph + vector store. Backed by CozoDB on Android
/// (via a Pigeon→Kotlin bridge); a `dart:ffi` implementation follows on Windows
/// in P15. The relationship graph and AI vector index live here as a **derived,
/// rebuildable index** beside the canonical Drift database (see
/// docs/GRAPH-SPEC.md). UI and feature code depend only on this interface, never
/// a concrete engine.
///
/// P10a establishes the foundation (open / schema / raw script / close). Typed
/// convenience methods (`relatedTo`, `vectorSearch`, `upsert*`, …) are added in
/// later P10 subphases as they're implemented.
abstract interface class GraphStore {
  /// Opens (or creates) the persistent store and ensures the base schema.
  ///
  /// Returns `false` (leaving [isAvailable] false) when the native engine can't
  /// run on this device — callers then disable graph features gracefully rather
  /// than crash. Throws [GraphException] only on a genuine open failure.
  Future<bool> open();

  /// Whether the store opened successfully and is usable.
  bool get isAvailable;

  /// Runs a CozoScript [script] with optional [params] (referenced as `$name`),
  /// returning the decoded result (`{headers: [...], rows: [...]}`).
  Future<Map<String, Object?>> runScript(
    String script, [
    Map<String, Object?> params,
  ]);

  /// Creates the deterministic node/edge relations if absent (idempotent).
  Future<void> ensureSchema();

  /// Closes the store and releases native resources.
  Future<void> close();
}
