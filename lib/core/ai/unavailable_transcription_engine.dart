import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/transcription_engine.dart';
import 'package:grabbit/core/ai/transcription_model.dart';

/// Graceful no-op [TranscriptionEngine] for platforms that can't run whisper
/// (non-Android until P15, CI, or before the native engine lands in P12e-2).
/// Never crashes — transcription simply stays off (AI-SPEC §1), and a captioned
/// item still gets its sidecar transcript via the existing P10f pipeline.
class UnavailableTranscriptionEngine implements TranscriptionEngine {
  const UnavailableTranscriptionEngine([this._model = whisperBase]);

  final TranscriptionModel _model;

  static const _ex = InferenceException(
    InferenceErrorCode.unavailable,
    'On-device transcription is not available on this device',
  );

  @override
  TranscriptionModel get model => _model;

  @override
  bool get isAvailable => false;

  @override
  Future<void> downloadModel({
    void Function(double progress)? onProgress,
  }) async => throw _ex;

  @override
  Future<bool> ensureReady() async => false;

  @override
  Future<TranscriptResult> transcribe(String audioPath, {String? language}) =>
      throw _ex;

  @override
  Future<void> close() async {}
}
