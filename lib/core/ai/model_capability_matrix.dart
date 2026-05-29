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

  /// The embedder eligible at [tier], falling back to the universal floor
  /// ([geckoEmbedder]) if a tier has no explicit entry.
  EmbedderModel embedderFor(DeviceTier tier) =>
      _embedders[tier] ?? geckoEmbedder;

  // Every tier runs Gecko today (Apache-2.0, ~114 MB) — the universal floor.
  static const Map<DeviceTier, EmbedderModel> _defaultEmbedders = {
    DeviceTier.low: geckoEmbedder,
    DeviceTier.mid: geckoEmbedder,
    DeviceTier.high: geckoEmbedder,
  };
}
