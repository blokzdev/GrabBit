/// Pure ranking for tag co-occurrence (P10c-c-2). Like `related_ranking.dart`,
/// it has no Flutter/engine/AI imports: `GraphQueryService` feeds it the decoded
/// `[other, tag]` rows and it returns the top tags by support. Unit-testable in
/// isolation.
library;

/// A tag and how many distinct source items support it.
class TagCount {
  const TagCount(this.tag, this.count);

  final String tag;
  final int count;
}

/// Ranks tags by how many **distinct** source items carry them (desc), ties
/// broken alphabetically for stable output. Each pair is `(source, tag)`;
/// duplicate pairs are de-duplicated, so a single item can't inflate a tag's
/// count. Tags in [exclude] are dropped. Returns at most [limit] tags.
List<TagCount> rankCoOccurringTags(
  Iterable<({String source, String tag})> pairs, {
  Set<String> exclude = const {},
  int limit = 12,
}) {
  final sources = <String, Set<String>>{};
  for (final p in pairs) {
    if (exclude.contains(p.tag)) continue;
    (sources[p.tag] ??= <String>{}).add(p.source);
  }
  final tags = sources.keys.toList()
    ..sort((a, b) {
      final byCount = sources[b]!.length.compareTo(sources[a]!.length);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  final top = tags.length > limit ? tags.sublist(0, limit) : tags;
  return [for (final t in top) TagCount(t, sources[t]!.length)];
}
