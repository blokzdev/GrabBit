import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:grabbit/core/ai/embedder_engine.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/model_catalog.dart';

/// `flutter_gemma` (embedder-only) [EmbedderEngine] for Android. Never loads an
/// LLM — only the [EmbedderModel] it's constructed with (chosen by
/// `embedderEngineFor`). The model download is opt-in (gated by the
/// `semanticSearchEnabled` setting); construction is cheap and side-effect free,
/// so the keepAlive provider can build it eagerly while staying inert until the
/// user enables semantic search.
class FlutterGemmaEmbedderEngine implements EmbedderEngine {
  FlutterGemmaEmbedderEngine(this._model);

  final EmbedderModel _model;

  EmbeddingModel? _loaded;
  bool _initialized = false;

  String get _modelFile => Uri.parse(_model.modelUrl).pathSegments.last;
  String get _tokenizerFile => Uri.parse(_model.tokenizerUrl).pathSegments.last;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await FlutterGemma.initialize();
    _initialized = true;
  }

  @override
  EmbedderModel get model => _model;

  @override
  bool get isAvailable => _loaded != null;

  @override
  int get dimension => _model.dimension;

  Future<bool> _filesInstalled() async {
    await _ensureInit();
    return await FlutterGemma.isModelInstalled(_modelFile) &&
        await FlutterGemma.isModelInstalled(_tokenizerFile);
  }

  @override
  Future<void> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    try {
      await _ensureInit();
      // The model file dwarfs the tokenizer, so it gets ~98% of the bar.
      await FlutterGemma.installEmbedder()
          .modelFromNetwork(_model.modelUrl)
          .tokenizerFromNetwork(_model.tokenizerUrl)
          .withModelProgress((p) => onProgress?.call((p / 100) * 0.98))
          .withTokenizerProgress(
            (p) => onProgress?.call(0.98 + (p / 100) * 0.02),
          )
          .install();
      onProgress?.call(1);
      await _load();
    } on InferenceException {
      rethrow;
    } catch (e) {
      throw InferenceException(
        InferenceErrorCode.downloadFailed,
        'Failed to download the embedder model',
        cause: e,
      );
    }
  }

  Future<void> _load() async {
    try {
      // install() set the active embedding spec; load the runnable model.
      _loaded = await FlutterGemma.getActiveEmbedder();
    } catch (e) {
      _loaded = null;
      throw InferenceException(
        InferenceErrorCode.loadFailed,
        'Failed to load the embedder model',
        cause: e,
      );
    }
  }

  @override
  Future<bool> ensureReady() async {
    if (_loaded != null) return true;
    try {
      if (!await _filesInstalled()) return false;
      // Re-establish the active spec across restarts without re-downloading —
      // install() is idempotent and skips the fetch when files are present.
      await FlutterGemma.installEmbedder()
          .modelFromNetwork(_model.modelUrl)
          .tokenizerFromNetwork(_model.tokenizerUrl)
          .install();
      await _load();
      return _loaded != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<double>> embed(String text) async {
    final loaded = _loaded;
    if (loaded == null) {
      throw const InferenceException(
        InferenceErrorCode.unavailable,
        'The embedder model is not loaded',
      );
    }
    try {
      return await loaded.generateEmbedding(text);
    } catch (e) {
      throw InferenceException(
        InferenceErrorCode.embedFailed,
        'Failed to embed text',
        cause: e,
      );
    }
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    final loaded = _loaded;
    if (loaded == null) {
      throw const InferenceException(
        InferenceErrorCode.unavailable,
        'The embedder model is not loaded',
      );
    }
    if (texts.isEmpty) return const [];
    try {
      return await loaded.generateEmbeddings(texts);
    } catch (e) {
      throw InferenceException(
        InferenceErrorCode.embedFailed,
        'Failed to embed text batch',
        cause: e,
      );
    }
  }

  @override
  Future<void> close() async {
    await _loaded?.close();
    _loaded = null;
  }
}
