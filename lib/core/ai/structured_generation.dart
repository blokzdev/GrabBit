/// Types for **function-calling / typed-tool-fill** generation. These shape the
/// `generateStructured` seam on [GenerationEngine] for the **Things Engine**
/// curator's "narrow-then-fill" step (P15, ADR-0002). The flutter_gemma-backed
/// engine implements the fill (P15a) via `structured_tool_adapter.dart`; the
/// curator that builds [StructuredToolDef]s from the schema.org vocabulary lands
/// in P15b. Kept deliberately thin: the plugin-neutral contract between the pure
/// curator and the engine.
library;

/// One tool the model may "fill": a named, described typed schema. [parameters]
/// is a JSON-schema-ish map (`{name: {type, description, ...}}`) — the curator
/// (P15b) builds these from the schema.org vocabulary for the candidate Thing
/// type(s).
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
/// asset at the boundary by the curator — ADR-0001).
class StructuredResult {
  const StructuredResult({required this.toolName, required this.arguments});

  /// The [StructuredToolDef.name] the model chose to fill.
  final String toolName;

  /// The filled arguments (property → value).
  final Map<String, Object?> arguments;
}
