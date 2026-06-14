import 'package:grabbit/core/ai/generation_model.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/ai/transcription_model.dart';
import 'package:grabbit/core/device/device_profile.dart';

/// Maps an on-device AI capability to the model(s) eligible at each [DeviceTier]
/// — the gating layer between the device tier and the model catalog (AI-SPEC §2).
///
/// P12a populates only the **embedder** dimension (the universal floor); the
/// generation, transcription, and structured-extraction rows arrive with their
/// subphases (P12d–P12f), and the multilingual embedder enters capable tiers in
/// P12c. Today every tier maps to [geckoEmbedder], so [embedderFor] is the
/// selection *mechanism*, not yet a per-tier choice.
class ModelCapabilityMatrix {
  const ModelCapabilityMatrix({Map<DeviceTier, EmbedderModel>? embedders})
    : _embedders = embedders ?? _defaultEmbedders;

  final Map<DeviceTier, EmbedderModel> _embedders;

  /// The **default** embedder at [tier] — Gecko everywhere (the universal floor).
  /// A heavier model is never forced; it's an opt-in override (P12c-3), so this
  /// stays Gecko at every tier.
  EmbedderModel embedderFor(DeviceTier tier) =>
      _embedders[tier] ?? geckoEmbedder;

  /// Embedders a device of [tier] may select (P12c-3) — the offer set the UI
  /// shows and the eligibility guard `activeEmbedderModelProvider` enforces.
  /// Gecko is universal; the multilingual MiniLM is offered on capable tiers
  /// (mid/high) — low-end stays on Gecko.
  List<EmbedderModel> eligibleEmbedders(DeviceTier tier) => switch (tier) {
    DeviceTier.low => const [geckoEmbedder],
    DeviceTier.mid ||
    DeviceTier.high => const [geckoEmbedder, paraphraseMultilingualMiniLmL12V2],
  };

  /// Generation models a device of [tier] may select (P12d) — the picker's offer
  /// set and the eligibility guard `activeGenerationModelProvider` enforces.
  /// **Low tier gets none** (generation is gated off with a friendly reason);
  /// the ladder reaches the flagship rung only on high-tier hardware.
  List<GenerationModel> eligibleGenerationModels(DeviceTier tier) =>
      switch (tier) {
        DeviceTier.low => const [],
        DeviceTier.mid => const [smolLm2_135mInstruct, qwen3_0_6b],
        DeviceTier.high => const [qwen3_0_6b, qwen2_5_1_5b, gemma4E2b],
      };

  /// The default generation model offered at [tier] — the balanced pick, badged
  /// **Recommended** in the picker. Null on low tier (generation unavailable).
  GenerationModel? recommendedGenerationModel(DeviceTier tier) =>
      switch (tier) {
        DeviceTier.low => null,
        DeviceTier.mid || DeviceTier.high => qwen3_0_6b,
      };

  /// Transcription models a device of [tier] may select (P12e) — the picker's
  /// offer set and the eligibility guard `activeTranscriptionModelProvider`
  /// enforces. **No tier is gated off entirely** (a deliberate divergence from
  /// generation, where low = empty): low runs only whisper-tiny (a light,
  /// one-shot batch job), and the ladder climbs to the flagship on capable
  /// hardware (tiny drops off once base is the floor).
  List<TranscriptionModel> eligibleTranscriptionModels(DeviceTier tier) =>
      switch (tier) {
        DeviceTier.low => const [whisperTiny],
        DeviceTier.mid => const [whisperTiny, whisperBase],
        DeviceTier.high => const [
          whisperBase,
          whisperSmall,
          whisperLargeV3Turbo,
        ],
      };

  /// The default transcription model offered at [tier] — the balanced pick,
  /// badged **Recommended** in the picker. Whisper-tiny on low (its only option);
  /// whisper-base on mid/high.
  TranscriptionModel recommendedTranscriptionModel(DeviceTier tier) =>
      switch (tier) {
        DeviceTier.low => whisperTiny,
        DeviceTier.mid || DeviceTier.high => whisperBase,
      };

  /// **`structured_extraction` capability (P12f forward seam, ADR-0002).**
  /// Gates the `generateStructured` function-calling step the **Things Engine**
  /// curator (P15) will use. **Empty on every tier for now** — no feature before P15 drives it,
  /// and the function-calling model is undecided (FunctionGemma's Gemma license vs
  /// Qwen3-0.6B's Apache-2.0 — fork deferred to P13). Defined + gated so the v2
  /// fill step is already capability-aware; reuses [GenerationModel] once a model
  /// is chosen (no speculative catalog type while the list is empty).
  List<GenerationModel> eligibleStructuredExtractionModels(DeviceTier tier) =>
      const [];

  /// The default structured-extraction model at [tier] — **null everywhere** until
  /// the P13 function-calling model is vetted (see [eligibleStructuredExtractionModels]).
  GenerationModel? recommendedStructuredExtractionModel(DeviceTier tier) =>
      null;

  // Every tier runs Gecko by default (Apache-2.0, ~114 MB) — the universal floor.
  static const Map<DeviceTier, EmbedderModel> _defaultEmbedders = {
    DeviceTier.low: geckoEmbedder,
    DeviceTier.mid: geckoEmbedder,
    DeviceTier.high: geckoEmbedder,
  };
}
