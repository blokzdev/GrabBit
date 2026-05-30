import 'dart:io';

import 'package:grabbit/core/ai/flutter_gemma_embedder_engine.dart';
import 'package:grabbit/core/ai/embedder_engine.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/ai/model_download_service.dart';
import 'package:grabbit/core/ai/onnx_embedder_engine.dart';
import 'package:grabbit/core/ai/unavailable_embedder_engine.dart';

/// Maps a selected [EmbedderModel] to the [EmbedderEngine] that can run it on
/// this host — the runtime "registry" seam. P12 adds the `onnx` case for the
/// multilingual MiniLM engine; P12 chooses *which* model via the capability
/// matrix. A model whose runtime isn't available here falls back to the graceful
/// [UnavailableEmbedderEngine] (semantic features stay off, never crash), which
/// still reports the selected [model] so id/dimension stay correct everywhere.
EmbedderEngine embedderEngineFor(
  EmbedderModel model, {
  ModelDownloadService? downloads,
}) {
  switch (model.runtime) {
    case EmbedderRuntime.flutterGemma:
      if (Platform.isAndroid) return FlutterGemmaEmbedderEngine(model);
    case EmbedderRuntime.onnx:
      // onnxruntime is wired on Android (P12c-2); other hosts fall back.
      if (Platform.isAndroid && downloads != null) {
        return OnnxEmbedderEngine(model, downloads);
      }
  }
  return UnavailableEmbedderEngine(model);
}
