import 'package:grabbit/core/ai/model_download_service.dart';
import 'package:grabbit/core/ai/transcription_engine.dart';
import 'package:grabbit/core/ai/transcription_model.dart';
import 'package:grabbit/core/ai/unavailable_transcription_engine.dart';

/// Maps a selected [TranscriptionModel] to the [TranscriptionEngine] that runs it
/// on this host — the runtime "registry" seam (mirrors `embedderEngineFor` /
/// `generationEngineFor`). The real whisper.cpp engine (Android, file-based via
/// [downloads]) lands in **P12e-2**; until then every host gets the graceful
/// [UnavailableTranscriptionEngine] (transcription stays off, never crashes),
/// which still reports the selected [model].
TranscriptionEngine transcriptionEngineFor(
  TranscriptionModel model, {
  ModelDownloadService? downloads,
}) {
  // P12e-1 is pure-Dart scaffolding — no native engine yet (lands in P12e-2).
  return UnavailableTranscriptionEngine(model);
}
