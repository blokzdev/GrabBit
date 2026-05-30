import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:grabbit/core/ai/generation_engine.dart';
import 'package:grabbit/core/ai/generation_model.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/storage/disk_space_service.dart';
import 'package:path_provider/path_provider.dart';

/// Maps a [GenerationModel.modelTypeId] (a neutral catalog string) to the
/// flutter_gemma [ModelType] — kept here so the pure-Dart catalog never imports
/// the plugin. Unknown ids throw (a catalog/plugin mismatch is a bug, not a
/// runtime condition).
ModelType modelTypeForId(String id) => switch (id) {
  'general' => ModelType.general,
  'gemmaIt' => ModelType.gemmaIt,
  'gemma4' => ModelType.gemma4,
  'qwen' => ModelType.qwen,
  'qwen3' => ModelType.qwen3,
  'phi' => ModelType.phi,
  _ => throw ArgumentError('Unknown generation modelTypeId: $id'),
};

/// On-device LLM text generation via `flutter_gemma` (P12d-2), for Android. The
/// model is plugin-managed (downloaded + cached by flutter_gemma, like the Gecko
/// embedder) — there is no app-side hash. A **pre-download free-storage guard**
/// (these models are 143 MB–2.5 GB) avoids starting a doomed multi-GB fetch.
/// Mirrors `FlutterGemmaEmbedderEngine`'s lazy-init + `InferenceException`-wrap
/// idiom. Generation is opt-in + capability-gated; this engine is inert until
/// the user enables it and the model is downloaded.
class FlutterGemmaGenerationEngine implements GenerationEngine {
  FlutterGemmaGenerationEngine(
    this._model, {
    required this.diskSpace,
    Future<String> Function()? storageDirPath,
  }) : _storageDirPath = storageDirPath ?? _defaultStorageDir;

  final GenerationModel _model;
  final DiskSpaceService diskSpace;
  final Future<String> Function() _storageDirPath;

  InferenceModel? _loaded;
  bool _initialized = false;

  /// Headroom beyond the model itself (working files + safety margin).
  static const _headroomMb = 256;

  static Future<String> _defaultStorageDir() async =>
      (await getApplicationSupportDirectory()).path;

  ModelType get _modelType => modelTypeForId(_model.modelTypeId);
  String get _modelFile => Uri.parse(_model.modelUrl).pathSegments.last;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await FlutterGemma.initialize();
    _initialized = true;
  }

  @override
  GenerationModel get model => _model;

  @override
  bool get isAvailable => _loaded != null;

  @override
  Future<void> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    try {
      // Guard storage first — cheap, and avoids touching the plugin when the
      // multi-GB download obviously won't fit.
      await _guardStorage();
      await _ensureInit();
      await FlutterGemma.installModel(
        modelType: _modelType,
        fileType: ModelFileType.litertlm,
      ).fromNetwork(_model.modelUrl).withProgress((p) {
        onProgress?.call(p / 100);
      }).install();
      onProgress?.call(1);
      await _load();
    } on InferenceException {
      rethrow;
    } catch (e) {
      throw InferenceException(
        InferenceErrorCode.downloadFailed,
        'Failed to download the generation model',
        cause: e,
      );
    }
  }

  /// Rejects a download that obviously won't fit, before the multi-GB fetch.
  Future<void> _guardStorage() async {
    final space = await diskSpace.query(await _storageDirPath());
    final neededBytes = (_model.approxDownloadMb + _headroomMb) * 1024 * 1024;
    if (space.freeBytes < neededBytes) {
      throw InferenceException(
        InferenceErrorCode.downloadFailed,
        'Not enough free storage for ${_model.displayName} '
        '(~${_model.approxDownloadMb} MB).',
      );
    }
  }

  Future<void> _load() async {
    try {
      _loaded = await FlutterGemma.getActiveModel(
        maxTokens: _model.maxTokens,
        preferredBackend: PreferredBackend.gpu,
      );
    } catch (_) {
      // GPU backend can be unavailable on some devices — retry on CPU.
      try {
        _loaded = await FlutterGemma.getActiveModel(
          maxTokens: _model.maxTokens,
          preferredBackend: PreferredBackend.cpu,
        );
      } catch (e) {
        _loaded = null;
        throw InferenceException(
          InferenceErrorCode.loadFailed,
          'Failed to load the generation model',
          cause: e,
        );
      }
    }
  }

  @override
  Future<bool> ensureReady() async {
    if (_loaded != null) return true;
    try {
      await _ensureInit();
      if (!await FlutterGemma.isModelInstalled(_modelFile)) return false;
      // install() is idempotent and skips the fetch when the file is present —
      // it re-establishes the active spec across restarts without re-downloading.
      await FlutterGemma.installModel(
        modelType: _modelType,
        fileType: ModelFileType.litertlm,
      ).fromNetwork(_model.modelUrl).install();
      await _load();
      return _loaded != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<String> generate(String prompt, {String? systemPrompt}) async* {
    final loaded = _loaded;
    if (loaded == null) {
      throw const InferenceException(
        InferenceErrorCode.unavailable,
        'The generation model is not loaded',
      );
    }
    try {
      final chat = await loaded.createChat(
        modelType: _modelType,
        systemInstruction: systemPrompt,
      );
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) yield response.token;
      }
    } on InferenceException {
      rethrow;
    } catch (e) {
      throw InferenceException(
        InferenceErrorCode.generateFailed,
        'Failed to generate text',
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
