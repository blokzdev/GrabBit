import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/graph/graph_query_provider.dart';
import 'package:grabbit/core/things/thing_hydration.dart';

// Hand-written (returns Drift `MediaItem` rows): the shortest connection between
// two library items for the "How are these related?" chain screen (P13e-3a).

/// A resolved connection chain: the items along the shortest path (source first,
/// target last) and the [connectors] describing each hop between them.
class ConnectionPathView {
  const ConnectionPathView({required this.items, required this.connectors});

  final List<MediaItem> items;
  final List<String> connectors;
}

/// The shortest connection between `(source, target)`, hydrated to [MediaItem]s
/// for rendering. Every-device (graph only, no embedder). `null` when the graph
/// is unavailable, the items are the same/disconnected, or a path node has since
/// been deleted (so the screen shows "No connection found").
final connectionPathProvider =
    FutureProvider.family<ConnectionPathView?, (String source, String target)>((
      ref,
      pair,
    ) async {
      final path = await ref
          .watch(graphQueryServiceProvider)
          .pathBetween(pair.$1, pair.$2);
      if (path == null) return null;

      final nodes = await ref
          .watch(nodeHydrationProvider)
          .hydrateNodes(path.itemIds);
      final byId = {
        for (final n in nodes)
          if (n.media != null) n.id: n.media!,
      };

      final items = [
        for (final id in path.itemIds)
          if (byId[id] case final MediaItem m) m,
      ];
      // A path node was deleted since the index was built.
      if (items.length != path.itemIds.length) return null;
      return ConnectionPathView(items: items, connectors: path.connectors);
    });
