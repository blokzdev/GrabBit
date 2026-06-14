import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:grabbit/core/ai/structured_generation.dart';

/// The single seam between the pure-Dart curator's [StructuredToolDef]s (P15b)
/// and `flutter_gemma`'s function-calling API (P15a). Kept as pure top-level
/// functions so the mapping is unit-testable without a live model — the engine
/// just wires them around `createChat` / `generateChatResponseAsync`.

/// Maps a curator [StructuredToolDef] to a flutter_gemma [Tool] — a 1:1 field
/// copy ([parameters] is the JSON-schema-ish object the model fills).
Tool toGemmaTool(StructuredToolDef def) => Tool(
  name: def.name,
  description: def.description,
  parameters: Map<String, dynamic>.from(def.parameters),
);

/// The tool-calling mode for a candidate set (ADR-0002 narrow-then-fill): a
/// single confident candidate forces the fill ([ToolChoice.required] — the
/// "single-tool" branch); 2+ ambiguous candidates let the model pick among them
/// ([ToolChoice.auto] — the "narrowed-set" branch).
ToolChoice toolChoiceFor(List<StructuredToolDef> defs) =>
    defs.length == 1 ? ToolChoice.required : ToolChoice.auto;

/// Maps a flutter_gemma [FunctionCallResponse] back to the curator's
/// [StructuredResult] (the chosen `@type` + the filled arguments).
StructuredResult structuredResultFrom(FunctionCallResponse call) =>
    StructuredResult(
      toolName: call.name,
      arguments: Map<String, Object?>.from(call.args),
    );
