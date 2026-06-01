import 'dart:io';

import 'package:grabbit/core/ai/model_download_service.dart';
import 'package:grabbit/core/ai/transcription_engine.dart';
import 'package:grabbit/core/ai/transcription_model.dart';
import 'package:grabbit/core/ai/unavailable_transcription_engine.dart';
import 'package:grabbit/core/ai/whisper_transcription_engine.dart';
import 'package:grabbit/core/engine/android_ffmpeg_tools_engine.dart';

/// Maps a selected [TranscriptionModel] to the [TranscriptionEngine] that runs it
/// on this host — the runtime "registry" seam (mirrors `embedderEngineFor` /
/// `generationEngineFor`). On Android (with a [downloads] service) this is the
/// real whisper.cpp engine, transcoding via the same ffmpeg the Media Studio
/// uses; every other host gets the graceful [UnavailableTranscriptionEngine]
/// (transcription stays off, never crashes), which still reports the [model].
TranscriptionEngine transcriptionEngineFor(
  TranscriptionModel model, {
  ModelDownloadService? downloads,
}) {
  if (downloads != null && Platform.isAndroid) {
    return WhisperTranscriptionEngine(
      model,
      downloads,
      AndroidFfmpegToolsEngine(),
    );
  }
  return UnavailableTranscriptionEngine(model);
}
