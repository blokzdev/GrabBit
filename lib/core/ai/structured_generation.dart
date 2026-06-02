/// Forward-seam types for **function-calling / typed-tool-fill** generation
/// (P12f). These shape the `generateStructured` seam on [GenerationEngine] so the
/// **v2 Things Engine** curator's "narrow-then-fill" step (ADR-0002) can slot in
/// without reworking the AI engine contracts. **Inert in v1** — no v1 feature
/// calls `generateStructured`, and no shipped model implements it yet (the
/// function-calling model license fork — FunctionGemma vs Qwen3 — is deferred to
/// P13; see `docs/BACKLOG.md`). Kept deliberately thin: just enough to type the
/// future fill call without committing to internals.
library;

/// One tool the model may "fill": a named, described typed schema. [parameters]
/// is a JSON-schema-ish map (`{name: {type, description, ...}}`) — the v2 curator
/// builds these from the schema.org vocabulary for the candidate Thing type(s).
class StructuredToolDef {
  const StructuredToolDef({
    required this.name,
    required this.description,
    this.parameters = const {},
  });

  /// Tool name — typically the target schema.org `@type` (e.g. `Recipe`).
  final String name;

  /// Natural-language description guiding the model's fill.
  final String description;

  /// JSON-schema-ish parameter definitions the model fills.
  final Map<String, Object?> parameters;
}

/// The model's structured output: which [toolName] it selected and the
/// [arguments] it filled (a JSON-object map, validated against the schema.org
/// asset at the boundary by the future curator — ADR-0001).
class StructuredResult {
  const StructuredResult({required this.toolName, required this.arguments});

  /// The [StructuredToolDef.name] the model chose to fill.
  final String toolName;

  /// The filled arguments (property → value).
  final Map<String, Object?> arguments;
}
