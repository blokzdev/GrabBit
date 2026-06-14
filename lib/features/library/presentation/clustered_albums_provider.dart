import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/graph/graph_query_provider.dart';
import 'package:grabbit/core/things/thing_hydration.dart';
import 'package:grabbit/features/library/presentation/suggested_albums_provider.dart';

// Hand-written (returns Drift `MediaItem` rows): thematic community clusters over
// the entity graph the user can save as a collection (P13e-1). Reuses the
// `SuggestedAlbum` model + screen.

/// "Discovered" albums from on-device **entity-graph community detection**
/// (P13e-1), hydrated to [MediaItem]s. Every-device — needs only the graph
/// store, no embedder (unlike [suggestedAlbumsProvider]). `[]` when the graph is
/// unavailable or nothing clusters.
final clusteredAlbumsProvider = FutureProvider<List<SuggestedAlbum>>((
  ref,
) async {
  final communities = await ref
      .watch(graphQueryServiceProvider)
      .communityClusters();
  if (communities.isEmpty) return const [];

  final db = ref.watch(appDatabaseProvider);
  final allIds = {for (final c in communities) ...c.items};
  final nodes = await ref
      .watch(nodeHydrationProvider)
      .hydrateNodes(allIds.toList());
  final byId = {
    for (final n in nodes)
      if (n.media != null) n.id: n.media!,
  };

  // Batched signals for labeling (one query each, no N+1).
  final uploaderById = {
    for (final r in await (db.select(
      db.mediaMetadata,
    )..where((t) => t.itemId.isIn(allIds.toList()))).get())
      r.itemId: r.uploader,
  };

  final albums = <SuggestedAlbum>[];
  for (final community in communities) {
    // Members may have been deleted since the graph was built.
    final items = [
      for (final id in community.items)
        if (byId[id] case final MediaItem m) m,
    ];
    if (items.length < 3) continue;
    albums.add(
      SuggestedAlbum(
        label: clusterLabel(
          items,
          dominantTag: community.dominantTag,
          uploaderById: uploaderById,
        ),
        items: items,
      ),
    );
  }
  return albums;
});

/// Labels a community by its **dominant shared signal** (P13e-1): the tag most
/// members share, else the most common uploader, else the most common site, else
/// the newest item's title (the Suggested-album style). Pure + unit-testable.
String clusterLabel(
  List<MediaItem> items, {
  String? dominantTag,
  Map<String, String?> uploaderById = const {},
}) {
  if (dominantTag != null && dominantTag.trim().isNotEmpty) {
    return "Around '${dominantTag.trim()}'";
  }
  final uploader = _mostCommon([for (final it in items) uploaderById[it.id]]);
  if (uploader != null) return 'Mostly $uploader';
  final site = _mostCommon([for (final it in items) it.site]);
  if (site != null) return 'Mostly $site';

  final rep = items.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
  final t = rep.title.trim();
  final short = t.length > 40 ? '${t.substring(0, 40).trimRight()}…' : t;
  return "Like '$short'";
}

/// The most frequent non-blank value with support ≥ 2 (ties → lexicographically
/// smallest); `null` if none stands out.
String? _mostCommon(List<String?> values) {
  final counts = <String, int>{};
  for (final v in values) {
    final s = v?.trim();
    if (s != null && s.isNotEmpty) counts[s] = (counts[s] ?? 0) + 1;
  }
  String? best;
  var bestCount = 0;
  counts.forEach((s, c) {
    if (c > bestCount ||
        (c == bestCount && best != null && s.compareTo(best!) < 0)) {
      best = s;
      bestCount = c;
    }
  });
  return bestCount >= 2 ? best : null; // a single occurrence isn't "common"
}
