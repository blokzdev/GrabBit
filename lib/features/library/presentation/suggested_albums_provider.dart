import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/graph/graph_query_provider.dart';
import 'package:grabbit/features/library/presentation/semantic_search_provider.dart';

// Hand-written (returns Drift `MediaItem` rows): a similarity-clustered grouping
// the user can save as a collection (P10c-d-2).

/// A suggested album: a similarity cluster of library items plus a derived label.
class SuggestedAlbum {
  const SuggestedAlbum({required this.label, required this.items});

  final String label;
  final List<MediaItem> items;
}

/// Suggested albums from on-device similarity clusters, hydrated to [MediaItem]s.
/// Returns `[]` unless the embedder is ready (so the Albums view shows no
/// Suggested section without AI), or when nothing clusters.
final suggestedAlbumsProvider = FutureProvider<List<SuggestedAlbum>>((
  ref,
) async {
  if (!await ref.watch(semanticSearchReadyProvider.future)) return const [];
  final clusters = await ref
      .watch(graphQueryServiceProvider)
      .similarityClusters();
  if (clusters.isEmpty) return const [];

  final db = ref.watch(appDatabaseProvider);
  final allIds = {for (final c in clusters) ...c};
  final found = await (db.select(
    db.mediaItems,
  )..where((t) => t.id.isIn(allIds.toList()))).get();
  final byId = {for (final m in found) m.id: m};

  final albums = <SuggestedAlbum>[];
  for (final cluster in clusters) {
    // Members may have been deleted since the index was built.
    final items = [
      for (final id in cluster)
        if (byId[id] case final MediaItem m) m,
    ];
    if (items.length < 3) continue;
    albums.add(SuggestedAlbum(label: _label(items), items: items));
  }
  return albums;
});

/// Labels a cluster by its newest item's title (truncated) — a recognisable
/// anchor. Richer naming (dominant tag/uploader, LLM) is P12.
String _label(List<MediaItem> items) {
  final rep = items.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
  final t = rep.title.trim();
  final short = t.length > 40 ? '${t.substring(0, 40).trimRight()}…' : t;
  return "Like '$short'";
}
