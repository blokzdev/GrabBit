import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/graph/graph_query_provider.dart';
import 'package:grabbit/features/library/presentation/rediscover.dart';

// Hand-written (returns Drift `MediaItem` rows): central-but-stale items for the
// "Rediscover" strip (P13e-2).

/// Items to **resurface** — central in the library graph (PageRank) yet not
/// opened recently — for the Dashboard/Library "Rediscover" strip. Every-device
/// (graph only, no embedder). `[]` when the graph is unavailable or nothing
/// qualifies, so the strip simply hides.
final rediscoverProvider = FutureProvider<List<MediaItem>>((ref) async {
  final centrality = await ref
      .watch(graphQueryServiceProvider)
      .itemCentrality();
  if (centrality.isEmpty) return const [];

  final db = ref.watch(appDatabaseProvider);
  final found = await (db.select(
    db.mediaItems,
  )..where((t) => t.id.isIn(centrality.keys.toList()))).get();
  final byId = {for (final m in found) m.id: m};

  final ranked = rankRediscover(
    centrality: centrality,
    lastTouchById: {
      for (final m in found) m.id: m.lastAccessedAt ?? m.createdAt,
    },
    now: DateTime.now(),
  );
  return [
    for (final id in ranked)
      if (byId[id] case final MediaItem m) m,
  ];
});
