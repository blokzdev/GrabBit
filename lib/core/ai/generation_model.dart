/// The on-device runtime that backs a [GenerationModel]. `generationEngineFor`
/// (see `generation_engine_factory.dart`) maps each value to a concrete
/// [GenerationEngine]. Generation models are **plugin-managed** (flutter_gemma
/// downloads + caches them, like the Gecko embedder), so — unlike file-based
/// embedders — they carry no app-side `ModelFile`/SHA-256.
enum GenerationRuntime { flutterGemma }

/// The capability/size band of a [GenerationModel] — drives the picker badge so
/// a user can trade speed for quality knowingly (P12d).
enum GenerationModelClass {
  /// Tiny, runs widely; fastest, lightest output.
  small,

  /// The balanced default (the per-tier **recommended** pick).
  balanced,

  /// Larger; better quality, more RAM + a bigger download.
  large,

  /// Flagship-only; the strongest option, large download + high RAM.
  flagship,
}

/// An on-device text-generation model (P12d). All shipped models are
/// **Apache-2.0 / ungated** to keep GrabBit's off-store redistribution posture
/// clean (CLAUDE.md §10; no Gemma use-policy, no token-gated downloads, no
/// AICore-managed Gemini Nano). Selection is tier-eligible + opt-in; the runtime
/// (flutter_gemma) handles the download, so there is no app-side hash here.
class GenerationModel {
  const GenerationModel({
    required this.id,
    required this.displayName,
    required this.modelUrl,
    required this.modelTypeId,
    required this.approxDownloadMb,
    required this.maxTokens,
    required this.license,
    required this.modelClass,
    required this.blurb,
    this.runtime = GenerationRuntime.flutterGemma,
  });

  /// Stable identifier, persisted as the user's selection.
  final String id;

  /// Human-facing name shown in the picker.
  final String displayName;

  /// HTTPS URL of the LiteRT/`.task` model (consumed by flutter_gemma in P12d-2).
  final String modelUrl;

  /// Neutral key mapped to a flutter_gemma `ModelType` in the d-2 engine (kept
  /// as a string so this pure-Dart catalog doesn't import the plugin).
  final String modelTypeId;

  /// Approximate download size in MB, surfaced in the picker.
  final int approxDownloadMb;

  /// Generation context window (tokens).
  final int maxTokens;

  /// SPDX-ish license tag (all shipped models are Apache-2.0) — a posture guard.
  final String license;

  /// The size/capability band — drives the picker badge.
  final GenerationModelClass modelClass;

  /// One-line "smaller & faster" / "larger & better" style description.
  final String blurb;

  /// Which on-device runtime serves this model — the factory routes on it.
  final GenerationRuntime runtime;
}

/// **Small** — SmolLM2-135M-Instruct (Apache-2.0): the lightest rung, runs
/// widely; a direct upgrade over SmolLM1 on instruction-following. Exact URL /
/// quant pinned at P12d-2 build (gated on a flutter_gemma-loadable build).
const GenerationModel smolLm2_135mInstruct = GenerationModel(
  id: 'smollm2-135m-instruct',
  displayName: 'SmolLM2 135M',
  // TODO(P12d-2): pin the exact LiteRT/.task URL + quant at build time.
  modelUrl: '',
  modelTypeId: 'general',
  approxDownloadMb: 100,
  maxTokens: 1024,
  license: 'Apache-2.0',
  modelClass: GenerationModelClass.small,
  blurb: 'Smaller & faster — lightest on-device model.',
);

/// **Balanced (recommended)** — Qwen3-0.6B (Apache-2.0, ungated): the default
/// pick on capable devices. (P12d-2 prefers a Qwen3.5-0.8B LiteRT build if one
/// exists; this is the confirmed fallback.)
const GenerationModel qwen3_0_6b = GenerationModel(
  id: 'qwen3-0.6b',
  displayName: 'Qwen3 0.6B',
  modelUrl: '', // TODO(P12d-2): pin LiteRT URL + quant.
  modelTypeId: 'qwen3',
  approxDownloadMb: 400,
  maxTokens: 2048,
  license: 'Apache-2.0',
  modelClass: GenerationModelClass.balanced,
  blurb: 'Recommended — best balance of quality and size.',
);

/// **Large** — Qwen2.5-1.5B (Apache-2.0): stronger, notably better at structured
/// output than similar-size alternatives (matters for later structured/tagging
/// features). High-tier; bigger download + RAM.
const GenerationModel qwen2_5_1_5b = GenerationModel(
  id: 'qwen2.5-1.5b-instruct',
  displayName: 'Qwen2.5 1.5B',
  modelUrl: '', // TODO(P12d-2): pin LiteRT URL + quant.
  modelTypeId: 'qwen',
  approxDownloadMb: 1024,
  maxTokens: 2048,
  license: 'Apache-2.0',
  modelClass: GenerationModelClass.large,
  blurb: 'Larger & better — stronger answers, more RAM.',
);

/// **Flagship** — Qwen3-4B (Apache-2.0): the strongest on-device option, for
/// high-end devices only; large download + high RAM.
const GenerationModel qwen3_4b = GenerationModel(
  id: 'qwen3-4b',
  displayName: 'Qwen3 4B',
  modelUrl: '', // TODO(P12d-2): pin LiteRT URL + quant.
  modelTypeId: 'qwen3',
  approxDownloadMb: 2600,
  maxTokens: 4096,
  license: 'Apache-2.0',
  modelClass: GenerationModelClass.flagship,
  blurb: 'Flagship — best quality; large download, needs lots of RAM.',
);

/// Every generation model GrabBit knows about — the lookup set for a persisted
/// selection (P12d).
const List<GenerationModel> allGenerationModels = [
  smolLm2_135mInstruct,
  qwen3_0_6b,
  qwen2_5_1_5b,
  qwen3_4b,
];

/// Resolves a persisted generation [id] to its catalog entry, or null if unknown
/// (e.g. a removed model) — callers fall back to the tier recommendation.
GenerationModel? generationModelById(String id) {
  for (final m in allGenerationModels) {
    if (m.id == id) return m;
  }
  return null;
}
