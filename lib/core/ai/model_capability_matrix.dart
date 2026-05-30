import 'package:grabbit/core/ai/model_catalog.dart';
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

  // Every tier runs Gecko by default (Apache-2.0, ~114 MB) — the universal floor.
  static const Map<DeviceTier, EmbedderModel> _defaultEmbedders = {
    DeviceTier.low: geckoEmbedder,
    DeviceTier.mid: geckoEmbedder,
    DeviceTier.high: geckoEmbedder,
  };
}
