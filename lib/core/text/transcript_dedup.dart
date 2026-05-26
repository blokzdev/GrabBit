/// Pure caption→transcript joiner (P10f). Zero-dependency: no Flutter, engine,
/// or AI imports — runs on any device, synchronously, offline. Collapses the
/// rolling, overlapping cues that auto-captions emit into clean lines, keeping
/// each line's start time (P10f-4). Unit-testable in isolation.
library;

import 'dart:convert';

/// One de-duplicated transcript line plus the playback time it starts at.
class TranscriptCue {
  const TranscriptCue({required this.start, required this.text});

  factory TranscriptCue.fromJson(Map<String, dynamic> json) => TranscriptCue(
    start: Duration(milliseconds: (json['t'] as num).toInt()),
    text: json['x'] as String,
  );

  final Duration start;
  final String text;

  Map<String, dynamic> toJson() => {'t': start.inMilliseconds, 'x': text};
}

/// Maximum word overlap searched between the running output's tail and the
/// next caption cue. Auto-caption rollover is short (a line or two), so a
/// small window keeps this linear without missing real overlaps.
const int _overlapWindow = 40;

/// Collapses ordered, possibly-overlapping caption [cues] into clean,
/// de-duplicated lines — each keeping the start time of the cue that
/// introduced its new words.
///
/// Auto-captions repeat the previous cue's tail (e.g. `"a b c"` then `"b c d"`);
/// this trims the longest suffix/prefix overlap so the text reads continuously.
/// Cues that add nothing new (exact duplicates / fully contained) are dropped.
/// Order is preserved. Deterministic; never throws.
List<TranscriptCue> captionsToTimedTranscript(List<TranscriptCue> cues) {
  final out = <String>[];
  final lines = <TranscriptCue>[];
  for (final cue in cues) {
    final words = cue.text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) continue;
    final fresh = _appendNew(out, words);
    if (fresh.isNotEmpty) {
      lines.add(TranscriptCue(start: cue.start, text: fresh.join(' ')));
    }
  }
  return lines;
}

/// The flat transcript: the de-duplicated lines joined into continuous text.
/// This is the canonical text the summary/search/embeddings consume; defining
/// it via [captionsToTimedTranscript] keeps flat and timed forms in lock-step.
/// Returns `''` when there is no usable text.
String captionsToTranscript(List<String> lines) => captionsToTimedTranscript([
  for (final l in lines) TranscriptCue(start: Duration.zero, text: l),
]).map((c) => c.text).join(' ');

/// Appends the words of a cue not already covered by the tail of [out]
/// (longest suffix/prefix overlap), mutating [out], and returns just the
/// newly-appended words.
List<String> _appendNew(List<String> out, List<String> words) {
  final maxK = [
    words.length,
    out.length,
    _overlapWindow,
  ].reduce((a, b) => a < b ? a : b);
  var k = 0;
  for (var cand = maxK; cand >= 1; cand--) {
    if (_tailMatchesHead(out, words, cand)) {
      k = cand;
      break;
    }
  }
  final fresh = words.sublist(k);
  out.addAll(fresh);
  return fresh;
}

/// Whether the last [n] words of [tail] equal the first [n] words of [head].
bool _tailMatchesHead(List<String> tail, List<String> head, int n) {
  final offset = tail.length - n;
  for (var i = 0; i < n; i++) {
    if (tail[offset + i] != head[i]) return false;
  }
  return true;
}

/// Serializes de-duplicated [cues] for storage (`MediaMetadata.transcriptCues`).
String encodeCues(List<TranscriptCue> cues) =>
    jsonEncode([for (final c in cues) c.toJson()]);

/// Parses stored cues JSON; returns `const []` for empty/blank input.
List<TranscriptCue> decodeCues(String json) {
  if (json.trim().isEmpty) return const [];
  return [
    for (final e in jsonDecode(json) as List)
      TranscriptCue.fromJson(e as Map<String, dynamic>),
  ];
}
