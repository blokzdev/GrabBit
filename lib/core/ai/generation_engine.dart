import 'package:grabbit/core/ai/generation_model.dart';
import 'package:grabbit/core/ai/structured_generation.dart';

/// On-device **text generation** abstraction (P12d) — the sibling of the
/// embedder-bound `EmbedderEngine`. Kept separate because generation uses its
/// own (much larger) model with its own lifecycle, and the active embedder may
/// be a runtime (onnx) that can't generate at all. Implementations are
/// capability-gated; an ineligible device gets the [UnavailableGenerationEngine]
/// no-op (graceful, never a crash — AI-SPEC §1). The engine is inert until the
/// user opts in and the model is downloaded.
abstract interface class GenerationEngine {
  /// The generation model this engine serves (id, size, runtime).
  GenerationModel get model;

  /// Whether the model is downloaded, loaded, and ready to [generate].
  bool get isAvailable;

  /// Downloads the model (the only AI-related network call), opt-in. [onProgress]
  /// reports 0.0–1.0. Idempotent; throws [InferenceErrorCode.downloadFailed].
  Future<void> downloadModel({void Function(double progress)? onProgress});

  /// Ensures the model is downloaded and loaded; returns whether it's now
  /// [isAvailable]. Does **not** trigger a download — call [downloadModel] first.
  Future<bool> ensureReady();

  /// Streams the generated completion for [prompt] token-by-token. [systemPrompt]
  /// optionally sets the assistant's behaviour. Emits a [Stream.error] of
  /// [InferenceException] (`unavailable`/`generateFailed`) on failure.
  Stream<String> generate(String prompt, {String? systemPrompt});

  /// **Function-calling / typed-tool-fill seam (P12f forward seam, ADR-0002).**
  /// Given a small set of [toolDefs], fills one and returns the structured
  /// result. **Inert in v1** — no v1 feature calls this, and no shipped model
  /// implements it yet (concrete engines throw [InferenceErrorCode.unsupported]);
  /// it is shaped now so the **P14 Things Engine** curator's "narrow-then-fill"
  /// step slots in without reworking this contract. Throws an [InferenceException]
  /// (`unavailable`/`unsupported`/`generateFailed`).
  Future<StructuredResult> generateStructured(
    List<StructuredToolDef> toolDefs,
    String prompt, {
    String? systemPrompt,
  });

  /// Releases native resources held by the loaded model.
  Future<void> close();
}
