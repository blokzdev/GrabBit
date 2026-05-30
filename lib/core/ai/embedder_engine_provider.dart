import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/ai/embedder_engine.dart';
import 'package:grabbit/core/ai/embedder_engine_factory.dart';
import 'package:grabbit/core/ai/model_capability_matrix.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/ai/model_download_service.dart';
import 'package:grabbit/core/device/device_tier_provider.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'embedder_engine_provider.g.dart';

/// The embedder model in use. Defaults to the device tier's model (Gecko, the
/// universal floor) and honors a persisted **install-global override**
/// (`selectedEmbedderModelId`, P12c-3) when it resolves, is eligible for the
/// tier, and its runtime can run on this host. Anything else (unknown id,
/// ineligible tier, an onnx model off-Android) **falls back to Gecko** — the
/// safety net that keeps semantic search working, never crashing. Changing the
/// result re-keys the embedding index (a full re-embed; see `GraphSyncService`).
@Riverpod(keepAlive: true)
EmbedderModel activeEmbedderModel(Ref ref) {
  final tier = ref.watch(activeDeviceTierProvider);
  const matrix = ModelCapabilityMatrix();
  final selectedId = ref.watch(
    settingsControllerProvider.select(
      (AsyncValue<SettingsModel> s) => s.value?.selectedEmbedderModelId ?? '',
    ),
  );
  final selected = selectedId.isEmpty ? null : embedderById(selectedId);
  if (selected != null &&
      matrix.eligibleEmbedders(tier).contains(selected) &&
      _runtimeRunsHere(selected)) {
    return selected;
  }
  return matrix.embedderFor(tier);
}

/// Whether [model]'s runtime can run on this host. The onnx runtime is Android
/// -only today (P12c-2); flutter_gemma's Gecko is the universal floor.
bool _runtimeRunsHere(EmbedderModel model) =>
    model.runtime != EmbedderRuntime.onnx || Platform.isAndroid;

/// Selects the [EmbedderEngine] for the active model + host platform. UI and
/// feature code depend on this provider, never a concrete runtime (mirrors
/// `graph_store_provider.dart` / `engine_provider.dart`).
///
/// Routing lives in `embedderEngineFor`: an unsupported runtime/platform yields
/// [UnavailableEmbedderEngine] (graceful degradation, per docs/AI-SPEC.md) —
/// semantic features simply stay off. The engine is inert until the user opts in
/// and downloads the model.
@Riverpod(keepAlive: true)
EmbedderEngine embedderEngine(Ref ref) => embedderEngineFor(
  ref.watch(activeEmbedderModelProvider),
  downloads: ref.watch(modelDownloadServiceProvider),
);
