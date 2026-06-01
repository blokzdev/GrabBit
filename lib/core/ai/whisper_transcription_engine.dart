import 'dart:async';
import 'dart:io';

import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/model_download_service.dart';
import 'package:grabbit/core/ai/transcription_engine.dart';
import 'package:grabbit/core/ai/transcription_mapping.dart';
import 'package:grabbit/core/ai/transcription_model.dart';
import 'package:grabbit/core/engine/media_tools_engine.dart';
import 'package:grabbit/core/engine/media_tools_ops.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';

/// On-device speech-to-text via **whisper.cpp** (`whisper_ggml_plus`, FFI), the
/// caption-less transcript fallback (P12e). Android-only here (Windows is v2);
/// other hosts get the [UnavailableTranscriptionEngine] from the factory.
///
/// The model is **app-managed**: downloaded + SHA-256-verified + cached by
/// [ModelDownloadService] (like the onnx embedder), and the cached `.bin` path
/// is handed to whisper as its `modelPath`. whisper.cpp needs a 16 kHz mono WAV,
/// so we transcode first with GrabBit's own ffmpeg ([MediaToolsEngine]) rather
/// than the package's ffmpeg companion — no extra native dependency.
class WhisperTranscriptionEngine implements TranscriptionEngine {
  WhisperTranscriptionEngine(this._model, this._downloads, this._mediaTools);

  final TranscriptionModel _model;
  final ModelDownloadService _downloads;
  final MediaToolsEngine _mediaTools;

  /// The resolved on-disk path of the downloaded ggml model, or null until
  /// [ensureReady] confirms it's installed. whisper.cpp loads the model per call
  /// (inside the package's isolate), so there is no persistent native handle.
  String? _modelPath;

  @override
  TranscriptionModel get model => _model;

  @override
  bool get isAvailable => _modelPath != null;

  @override
  Future<void> downloadModel({void Function(double progress)? onProgress}) =>
      _downloads.ensureDownloaded(_model.id, [
        _model.file,
      ], onProgress: onProgress);

  @override
  Future<bool> ensureReady() async {
    if (isAvailable) return true;
    try {
      if (!await _downloads.isInstalled(_model.id, [_model.file])) return false;
      _modelPath = await _downloads.pathFor(_model.id, _model.file.filename);
      return true;
    } catch (e) {
      _modelPath = null;
      throw InferenceException(
        InferenceErrorCode.loadFailed,
        'Failed to load the transcription model',
        cause: e,
      );
    }
  }

  @override
  Future<TranscriptResult> transcribe(
    String audioPath, {
    String? language,
  }) async {
    if (!await ensureReady()) {
      throw const InferenceException(
        InferenceErrorCode.unavailable,
        'The transcription model is not downloaded yet',
      );
    }
    final wavPath = await _toWav(audioPath);
    try {
      // The ctor's `model` enum is unused on the transcribe path — the actual
      // weights come from `modelPath` (our app-managed file). `lang: 'auto'`
      // detects the spoken language across the multilingual ggml ladder.
      final response = await const Whisper(model: WhisperModel.base).transcribe(
        transcribeRequest: TranscribeRequest(
          audio: wavPath,
          language: language ?? 'auto',
        ),
        modelPath: _modelPath!,
      );
      return transcriptResultFromSegments([
        for (final s in response.segments ?? const <WhisperTranscribeSegment>[])
          (start: s.fromTs, text: s.text),
      ]);
    } on InferenceException {
      rethrow;
    } catch (e) {
      throw InferenceException(
        InferenceErrorCode.transcribeFailed,
        'Failed to transcribe audio on-device',
        cause: e,
      );
    } finally {
      unawaited(File(wavPath).delete().then((_) {}, onError: (_) {}));
    }
  }

  @override
  Future<void> close() async {
    _modelPath = null;
  }

  /// Transcodes [inputPath] to a temp 16 kHz mono PCM WAV (whisper's required
  /// input) via ffmpeg, returning the WAV path. The caller deletes it.
  Future<String> _toWav(String inputPath) async {
    final tmp = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final outPath = '${tmp.path}/whisper_$stamp.wav';
    final job = MediaJob(
      id: 'whisper-wav-$stamp',
      args: wavForTranscriptionArgs(input: inputPath, output: outPath),
      outputPath: outPath,
    );
    await for (final event in _mediaTools.run(job)) {
      if (event.stage == ToolStage.error) {
        throw InferenceException(
          InferenceErrorCode.transcribeFailed,
          'Audio conversion failed: ${event.error ?? 'unknown error'}',
        );
      }
      if (event.stage == ToolStage.done) break;
    }
    return outPath;
  }
}
