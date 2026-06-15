import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/ai/generation_engine.dart';
import 'package:grabbit/core/ai/generation_engine_factory.dart';
import 'package:grabbit/core/ai/generation_model.dart';
import 'package:grabbit/core/ai/model_capability_matrix.dart';
import 'package:grabbit/core/ai/unavailable_generation_engine.dart';
import 'package:grabbit/core/device/device_tier_provider.dart';
import 'package:grabbit/core/storage/disk_space_service.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generation_provider.g.dart';

/// The active generation model (P12d), or **null** when generation isn't
/// available for this device's [DeviceTier] (low tier → no models). Honors the
/// persisted `selectedGenerationModelId` when it resolves and is tier-eligible;
/// otherwise falls back to the tier's **recommended** model. Opt-in (the engine
/// is inert until the user enables generation + downloads the model).
@Riverpod(keepAlive: true)
GenerationModel? activeGenerationModel(Ref ref) {
  final tier = ref.watch(activeDeviceTierProvider);
  const matrix = ModelCapabilityMatrix();
  final eligible = matrix.eligibleGenerationModels(tier);
  if (eligible.isEmpty) return null;

  final selectedId = ref.watch(
    settingsControllerProvider.select(
      (AsyncValue<SettingsModel> s) => s.value?.selectedGenerationModelId ?? '',
    ),
  );
  final selected = selectedId.isEmpty ? null : generationModelById(selectedId);
  if (selected != null && eligible.contains(selected)) return selected;
  return matrix.recommendedGenerationModel(tier);
}

/// The [GenerationEngine] for the active model + host platform (P12d). Routes via
/// `generationEngineFor`; a null active model (ineligible device) or unsupported
/// runtime yields the graceful [UnavailableGenerationEngine] — generation simply
/// stays off, never crashes. The real flutter_gemma engine lands in P12d-2.
@Riverpod(keepAlive: true)
GenerationEngine generationEngine(Ref ref) {
  final model = ref.watch(activeGenerationModelProvider);
  if (model == null) return const UnavailableGenerationEngine();
  return generationEngineFor(
    model,
    diskSpace: ref.watch(diskSpaceServiceProvider),
  );
}

/// Whether this device's [DeviceTier] can run **structured extraction** at all
/// (P15a/c) — i.e. the tier offers at least one function-calling-capable model
/// (low tier → none). Drives whether the "Extract Things" affordance is shown.
@Riverpod(keepAlive: true)
bool structuredExtractionSupported(Ref ref) {
  final tier = ref.watch(activeDeviceTierProvider);
  const matrix = ModelCapabilityMatrix();
  return matrix.eligibleStructuredExtractionModels(tier).isNotEmpty;
}

/// The model the curator would actually fill with (P15c): the **active
/// generation model** iff it's function-calling-capable on this tier, else null.
/// The engine loads the active model, so a non-FC selection (e.g. SmolLM2) yields
/// null — the UI then nudges the user to pick a compatible model in AI settings.
@Riverpod(keepAlive: true)
GenerationModel? activeStructuredExtractionModel(Ref ref) {
  final model = ref.watch(activeGenerationModelProvider);
  if (model == null) return null;
  final tier = ref.watch(activeDeviceTierProvider);
  const matrix = ModelCapabilityMatrix();
  return matrix.eligibleStructuredExtractionModels(tier).contains(model)
      ? model
      : null;
}
