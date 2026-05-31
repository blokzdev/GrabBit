import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/ai/model_capability_matrix.dart';
import 'package:grabbit/core/ai/model_download_service.dart';
import 'package:grabbit/core/ai/transcription_engine.dart';
import 'package:grabbit/core/ai/transcription_engine_factory.dart';
import 'package:grabbit/core/ai/transcription_model.dart';
import 'package:grabbit/core/device/device_tier_provider.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transcription_provider.g.dart';

/// The active transcription model (P12e). Honors the persisted
/// `selectedTranscriptionModelId` when it resolves and is tier-eligible;
/// otherwise falls back to the tier's **recommended** model. Never null — every
/// tier (incl. low) can run whisper-tiny. Opt-in: the engine is inert until the
/// user enables transcription + downloads the model.
@Riverpod(keepAlive: true)
TranscriptionModel activeTranscriptionModel(Ref ref) {
  final tier = ref.watch(activeDeviceTierProvider);
  const matrix = ModelCapabilityMatrix();
  final eligible = matrix.eligibleTranscriptionModels(tier);

  final selectedId = ref.watch(
    settingsControllerProvider.select(
      (AsyncValue<SettingsModel> s) =>
          s.value?.selectedTranscriptionModelId ?? '',
    ),
  );
  final selected = selectedId.isEmpty
      ? null
      : transcriptionModelById(selectedId);
  if (selected != null && eligible.contains(selected)) return selected;
  return matrix.recommendedTranscriptionModel(tier);
}

/// The [TranscriptionEngine] for the active model + host platform (P12e). Routes
/// via `transcriptionEngineFor`; an unsupported runtime/platform yields the
/// graceful [UnavailableTranscriptionEngine] — transcription simply stays off,
/// never crashes. The real whisper.cpp engine lands in P12e-2.
@Riverpod(keepAlive: true)
TranscriptionEngine transcriptionEngine(Ref ref) => transcriptionEngineFor(
  ref.watch(activeTranscriptionModelProvider),
  downloads: ref.watch(modelDownloadServiceProvider),
);
