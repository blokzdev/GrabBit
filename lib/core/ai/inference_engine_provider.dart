import 'package:grabbit/core/ai/inference_engine.dart';
import 'package:grabbit/core/ai/inference_engine_factory.dart';
import 'package:grabbit/core/ai/model_capability_matrix.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/device/device_tier_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inference_engine_provider.g.dart';

/// The embedder model in use, selected by the device's capability [DeviceTier]
/// via the [ModelCapabilityMatrix] (P12a). Today every tier maps to
/// [geckoEmbedder] (the universal floor), so this is the selection *mechanism*;
/// it becomes a real per-tier choice once P12c adds the multilingual embedder.
@Riverpod(keepAlive: true)
EmbedderModel activeEmbedderModel(Ref ref) => const ModelCapabilityMatrix()
    .embedderFor(ref.watch(activeDeviceTierProvider));

/// Selects the [InferenceEngine] for the active model + host platform. UI and
/// feature code depend on this provider, never a concrete runtime (mirrors
/// `graph_store_provider.dart` / `engine_provider.dart`).
///
/// Routing lives in `inferenceEngineFor`: an unsupported runtime/platform yields
/// [UnavailableInferenceEngine] (graceful degradation, per docs/AI-SPEC.md) —
/// semantic features simply stay off. The engine is inert until the user opts in
/// and downloads the model.
@Riverpod(keepAlive: true)
InferenceEngine inferenceEngine(Ref ref) =>
    inferenceEngineFor(ref.watch(activeEmbedderModelProvider));
