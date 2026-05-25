/// Pure scoring for "More like this" — blends semantic (vector) similarity with
/// deterministic graph signals into one ranked id list. No Flutter, no engine,
/// no AI imports: the whole ranking is unit-testable in isolation, and the
/// `GraphQueryService` just feeds it decoded query rows.
library;

/// A deterministic graph signal connecting two items (see `relatedNeighborsScript`).
enum RelatedSignal {
  uploader,
  playlist,
  tag,
  coDownload;

  /// Maps a CozoScript `kind` string to a signal, or `null` if unrecognised
  /// (so a future/unknown kind is ignored rather than crashing the blend).
  static RelatedSignal? fromKind(String kind) => switch (kind) {
    'uploader' => RelatedSignal.uploader,
    'playlist' => RelatedSignal.playlist,
    'tag' => RelatedSignal.tag,
    'codownload' => RelatedSignal.coDownload,
    _ => null,
  };
}

/// Blend weights. Semantic similarity is the strongest "like this" signal; a
/// shared creator/playlist is a strong explicit link; shared tags accrue (capped
/// so a few generic tags can't dominate); co-download is a weak temporal hint.
const double _wVector = 1.0;
const double _wUploader = 0.5;
const double _wPlaylist = 0.4;
const double _wTagEach = 0.15;
const int _tagCap = 3;
const double _wCoDownload = 0.2;

/// Ranks related items for a source item, nearest/strongest first.
///
/// [vectorHits] are `(id, cosineDistance)` from the HNSW search (may be empty
/// when the item has no embedding — then the result is graph-only). [signals]
/// are the per-connection graph rows. [exclude] drops ids (the source + exact
/// duplicates). Returns at most [limit] ids.
List<String> blendRelated({
  required List<({String id, double distance})> vectorHits,
  required List<({String id, RelatedSignal signal})> signals,
  Set<String> exclude = const {},
  int limit = 12,
}) {
  final scores = <String, double>{};
  final tagCounts = <String, int>{};
  // Tie-breaker: best (smallest) vector distance seen for an id; ids with no
  // vector hit sort after those that have one.
  final bestDistance = <String, double>{};

  void bump(String id, double delta) {
    if (exclude.contains(id)) return;
    scores[id] = (scores[id] ?? 0) + delta;
  }

  for (final hit in vectorHits) {
    if (exclude.contains(hit.id)) continue;
    final sim = (1 - hit.distance).clamp(0.0, 1.0);
    bump(hit.id, _wVector * sim);
    final prev = bestDistance[hit.id];
    if (prev == null || hit.distance < prev) {
      bestDistance[hit.id] = hit.distance;
    }
  }

  for (final s in signals) {
    if (exclude.contains(s.id)) continue;
    switch (s.signal) {
      case RelatedSignal.uploader:
        bump(s.id, _wUploader);
      case RelatedSignal.playlist:
        bump(s.id, _wPlaylist);
      case RelatedSignal.coDownload:
        bump(s.id, _wCoDownload);
      case RelatedSignal.tag:
        final n = (tagCounts[s.id] ?? 0);
        if (n < _tagCap) {
          bump(s.id, _wTagEach);
          tagCounts[s.id] = n + 1;
        }
    }
  }

  final ids = scores.keys.toList()
    ..sort((a, b) {
      final byScore = scores[b]!.compareTo(scores[a]!);
      if (byScore != 0) return byScore;
      final da = bestDistance[a] ?? double.infinity;
      final db = bestDistance[b] ?? double.infinity;
      final byDist = da.compareTo(db);
      return byDist != 0 ? byDist : a.compareTo(b);
    });
  return ids.length > limit ? ids.sublist(0, limit) : ids;
}
