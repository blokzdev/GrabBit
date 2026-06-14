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

  /// **`structured_extraction` capability (P15a, ADR-0002).** Gates the
  /// `generateStructured` function-calling step the **Things Engine** curator
  /// (P15) uses to fill typed schema.org Things. The fill runs on the resident
  /// generation model via `flutter_gemma` function-calling — so the offer set is
  /// the **function-calling-capable** subset of the generation ladder, all
  /// Apache-2.0: low is gated off (no generation), mid runs Qwen3-0.6B, and high
  /// adds Qwen2.5-1.5B + Gemma 4 E2B. SmolLM2-135M is excluded — it ignores tools
  /// (no function-calling), so it never appears here even though it's a mid-tier
  /// generation rung. This dissolves the long-deferred FunctionGemma-vs-Qwen3
  /// license fork (Gemma 4 went Apache-2.0).
  List<GenerationModel> eligibleStructuredExtractionModels(DeviceTier tier) =>
      switch (tier) {
        DeviceTier.low => const [],
        DeviceTier.mid => const [qwen3_0_6b],
        DeviceTier.high => const [qwen3_0_6b, qwen2_5_1_5b, gemma4E2b],
      };

  /// The default structured-extraction model at [tier], badged **Recommended**.
  /// Null on low (gated off); Qwen3-0.6B on mid (its only rung); **Gemma 4 E2B**
  /// on high — the strongest on-device function-calling fill.
  GenerationModel? recommendedStructuredExtractionModel(DeviceTier tier) =>
      switch (tier) {
        DeviceTier.low => null,
        DeviceTier.mid => qwen3_0_6b,
        DeviceTier.high => gemma4E2b,
      };

  // Every tier runs Gecko by default (Apache-2.0, ~114 MB) — the universal floor.
  static const Map<DeviceTier, EmbedderModel> _defaultEmbedders = {
    DeviceTier.low: geckoEmbedder,
    DeviceTier.mid: geckoEmbedder,
    DeviceTier.high: geckoEmbedder,
  };
}
