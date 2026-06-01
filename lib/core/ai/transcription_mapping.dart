import 'package:grabbit/core/ai/transcription_engine.dart';
import 'package:grabbit/core/text/transcript_dedup.dart';

/// Converts raw whisper segments into the canonical `(flat, cuesJson)` transcript
/// shape — **identical** to caption-derived transcripts (see
/// `TranscriptService.extractTimed`), so a whisper result flows through
/// `MetadataRepository.updateTranscript` unchanged and lights up FTS, the
/// semantic index, and the tap-to-seek view (P12e-3).
///
/// Runs the segments through the same `captionsToTimedTranscript` de-duplication
/// the caption path uses: whisper segments rarely overlap, but reusing it keeps
/// the two transcript sources byte-for-byte consistent and drops blank /
/// whitespace-only segments. Pure Dart — no plugin import — so it's unit-tested
/// without touching native code.
TranscriptResult transcriptResultFromSegments(
  Iterable<({Duration start, String text})> segments,
) {
  final cues = captionsToTimedTranscript([
    for (final s in segments)
      TranscriptCue(start: s.start, text: s.text.trim()),
  ]);
  return (flat: cues.map((c) => c.text).join(' '), cuesJson: encodeCues(cues));
}
