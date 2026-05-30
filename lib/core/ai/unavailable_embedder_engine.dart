import 'package:grabbit/core/ai/embedder_engine.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/model_catalog.dart';

/// Graceful no-op [EmbedderEngine] for platforms without the native embedder
/// (Windows until P15, CI, any other host). [isAvailable] is always false, so
/// callers disable semantic features cleanly; [embed]/[downloadModel] throw
/// [InferenceErrorCode.unavailable] rather than crash.
class UnavailableEmbedderEngine implements EmbedderEngine {
  const UnavailableEmbedderEngine([this._model = geckoEmbedder]);

  final EmbedderModel _model;

  static const _ex = InferenceException(
    InferenceErrorCode.unavailable,
    'On-device AI is not available on this platform',
  );

  @override
  EmbedderModel get model => _model;

  @override
  bool get isAvailable => false;

  @override
  int get dimension => _model.dimension;

  @override
  Future<void> downloadModel({
    void Function(double progress)? onProgress,
  }) async => throw _ex;

  @override
  Future<bool> ensureReady() async => false;

  @override
  Future<List<double>> embed(String text) async => throw _ex;

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async => throw _ex;

  @override
  Future<void> close() async {}
}
