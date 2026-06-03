/// Pure decision for whether "Ask your library" (P13d) can run, and at what
/// level — so the UI gates consistently and d-3's retrieval-only fallback has a
/// single source of truth.
library;

/// What the Ask feature can do on this device right now.
enum RagAvailability {
  /// No retrieval index (no embedder / graph) — the feature can't run.
  unavailable,

  /// Retrieval works but there's no generation model (low/ineligible tier) →
  /// answer with "most relevant items" only (d-3 fallback), no LLM.
  retrievalOnly,

  /// Full GraphRAG: retrieve + generate a grounded, cited answer.
  full,
}

/// [generationEligible] is whether the device tier offers a generation model;
/// [embedderReady] is whether semantic search (the query embedder) is ready;
/// [graphAvailable] is whether the on-device graph/vector store is usable.
RagAvailability ragAvailability({
  required bool generationEligible,
  required bool embedderReady,
  required bool graphAvailable,
}) {
  if (!embedderReady || !graphAvailable) return RagAvailability.unavailable;
  return generationEligible
      ? RagAvailability.full
      : RagAvailability.retrievalOnly;
}
