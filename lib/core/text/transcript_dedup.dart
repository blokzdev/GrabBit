/// Pure caption→transcript joiner (P10f). Zero-dependency: no Flutter, engine,
/// or AI imports — runs on any device, synchronously, offline. Collapses the
/// rolling, overlapping cues that auto-captions emit into clean flowing text.
/// Unit-testable in isolation.
library;

/// Maximum word overlap searched between the running output's tail and the
/// next caption line. Auto-caption rollover is short (a line or two), so a
/// small window keeps this linear without missing real overlaps.
const int _overlapWindow = 40;

/// Joins ordered caption cue [lines] into a single de-duplicated transcript.
///
/// Auto-captions repeat the previous cue's tail (e.g. `"a b c"` then
/// `"b c d"`); this merges by trimming the longest suffix/prefix overlap so the
/// result reads as continuous text. Exact duplicates and fully-contained lines
/// contribute nothing. Order is preserved. Returns `''` when there is no usable
/// text. Deterministic; never throws.
String captionsToTranscript(List<String> lines) {
  final out = <String>[];
  for (final raw in lines) {
    // A single cue's text can itself hold multiple newline-separated rows.
    for (final part in raw.split('\n')) {
      final words = part
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      if (words.isEmpty) continue;
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
      out.addAll(words.sublist(k));
    }
  }
  return out.join(' ');
}

/// Whether the last [n] words of [tail] equal the first [n] words of [head].
bool _tailMatchesHead(List<String> tail, List<String> head, int n) {
  final offset = tail.length - n;
  for (var i = 0; i < n; i++) {
    if (tail[offset + i] != head[i]) return false;
  }
  return true;
}
