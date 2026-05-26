import 'package:grabbit/core/ai/inference_engine.dart';
import 'package:grabbit/core/ai/inference_engine_factory.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inference_engine_provider.g.dart';

/// The embedder model in use. The single **selection seam** — returns
/// [defaultEmbedder] today; P12's device-capability/tier system overrides this
/// to pick a model (e.g. a larger window, or the multilingual engine) by tier.
@Riverpod(keepAlive: true)
EmbedderModel activeEmbedderModel(Ref ref) => defaultEmbedder;

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
