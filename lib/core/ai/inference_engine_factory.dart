import 'dart:io';

import 'package:grabbit/core/ai/flutter_gemma_inference_engine.dart';
import 'package:grabbit/core/ai/inference_engine.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/ai/unavailable_inference_engine.dart';

/// Maps a selected [EmbedderModel] to the [InferenceEngine] that can run it on
/// this host — the runtime "registry" seam. P10g-3 adds the `onnx` case for the
/// multilingual MiniLM engine; P12 chooses *which* model via the capability
/// matrix. A model whose runtime isn't available here falls back to the graceful
/// [UnavailableInferenceEngine] (semantic features stay off, never crash), which
/// still reports the selected [model] so id/dimension stay correct everywhere.
InferenceEngine inferenceEngineFor(EmbedderModel model) {
  switch (model.runtime) {
    case EmbedderRuntime.flutterGemma:
      if (Platform.isAndroid) return FlutterGemmaInferenceEngine(model);
  }
  return UnavailableInferenceEngine(model);
}
