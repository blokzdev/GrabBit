import 'package:grabbit/core/ai/transcription_model.dart';

/// The output of a transcription pass — the **same shape** caption-derived
/// transcripts use (`TranscriptService.extractTimed`), so whisper output flows
/// through the existing `MetadataRepository.updateTranscript` seam unchanged:
/// [flat] plain text (summary/search/embeddings) + [cuesJson] timestamped lines
/// (the synced tap-to-seek view). Built with `transcript_dedup`'s `encodeCues`.
typedef TranscriptResult = ({String flat, String cuesJson});

/// On-device **speech-to-text** abstraction (P12e) — a sibling of `EmbedderEngine`
/// and `GenerationEngine`. Kept separate because transcription uses its own model
/// (whisper.cpp) with its own lifecycle. Implementations are capability-gated; an
/// unsupported device/platform gets the [UnavailableTranscriptionEngine] no-op
/// (graceful, never a crash — AI-SPEC §1). The engine is inert until the user
/// opts in and the model is downloaded. Whisper is strictly a **fallback** for
/// media without caption sidecars (P12e-3); captioned items prefer their sidecar.
abstract interface class TranscriptionEngine {
  /// The transcription model this engine serves (id, file, size).
  TranscriptionModel get model;

  /// Whether the model is downloaded, loaded, and ready to [transcribe].
  bool get isAvailable;

  /// Downloads the model (the only AI-related network call), opt-in. [onProgress]
  /// reports 0.0–1.0. Idempotent; throws [InferenceErrorCode.downloadFailed].
  Future<void> downloadModel({void Function(double progress)? onProgress});

  /// Ensures the model is downloaded and loaded; returns whether it's now
  /// [isAvailable]. Does **not** trigger a download — call [downloadModel] first.
  Future<bool> ensureReady();

  /// Transcribes the audio of the media file at [audioPath] (any container —
  /// the engine extracts/normalizes audio internally), returning the flat text +
  /// timestamped cues. [language] is an ISO code or null for auto-detect. Throws
  /// an [InferenceException] (`unavailable`/`transcribeFailed`) on failure.
  Future<TranscriptResult> transcribe(String audioPath, {String? language});

  /// Releases native resources held by the loaded model.
  Future<void> close();
}
