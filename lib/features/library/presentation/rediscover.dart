/// Pure "Rediscover" ranking (P13e-2): combine graph **centrality** with
/// **staleness** to resurface central-but-faded items. No Flutter/Drift imports
/// so the scoring is unit-testable; the provider supplies centrality (from the
/// graph) and per-item last-touch times (from Drift).
library;

/// Ranks items for the Rediscover strip: `score = centrality × staleness`, where
/// staleness grows with days since the item was last touched ([lastTouchById] =
/// `lastAccessedAt ?? createdAt`). Items touched within [freshWindow] are
/// **excluded** (they already live in "Recently opened"); staleness saturates at
/// [stalenessCapDays]. Returns the top [limit] ids, most-relevant first (ties →
/// more-stale, then id for stability). Items without a centrality score or a
/// known touch time are skipped.
List<String> rankRediscover({
  required Map<String, double> centrality,
  required Map<String, DateTime> lastTouchById,
  required DateTime now,
  Duration freshWindow = const Duration(days: 14),
  double stalenessCapDays = 30,
  int limit = 12,
}) {
  final scored = <({String id, double score, double days})>[];
  centrality.forEach((id, rank) {
    if (rank <= 0) return;
    final touched = lastTouchById[id];
    if (touched == null) return;
    final days = now.difference(touched).inSeconds / Duration.secondsPerDay;
    if (days < freshWindow.inSeconds / Duration.secondsPerDay) return;
    final staleness = (days / stalenessCapDays).clamp(0.0, 1.0);
    scored.add((id: id, score: rank * staleness, days: days));
  });

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final byDays = b.days.compareTo(a.days);
    return byDays != 0 ? byDays : a.id.compareTo(b.id);
  });
  return [for (final s in scored.take(limit)) s.id];
}
