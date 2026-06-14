import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';

/// A graph node id resolved for display/citation (P14e). [title] and [type] come
/// from the canonical `things` row when present; [media] is the backing
/// `MediaItem` (non-null for file-backed MediaObject Things) for rich rendering.
class HydratedNode {
  const HydratedNode({
    required this.id,
    required this.title,
    this.type,
    this.media,
  });

  final String id;

  /// Display title — the Thing's `name`, falling back to the media title.
  final String title;

  /// The schema.org `@type` (e.g. `VideoObject`), or null for a media-only id.
  final String? type;

  /// The backing media row, for rich card rendering; null for a non-media Thing.
  final MediaItem? media;
}

/// The single **Thing-aware hydration seam** the GraphRAG retriever and the
/// graph-feature providers resolve graph node ids through (GRAPH-SPEC §10 seam 2)
/// — resolving ids to the `things` table (MediaObject one type among many) rather
/// than hardcoding `media_items`.
class NodeHydration {
  NodeHydration(this._db);

  final AppDatabase _db;

  /// Resolves [ids] to [HydratedNode]s, Thing-first, **preserving input order**.
  /// One batched `things` read + one `media_items` read (no N+1). Ids resolving
  /// to neither are skipped.
  Future<List<HydratedNode>> hydrateNodes(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final unique = ids.toSet().toList();
    final things = await (_db.select(
      _db.things,
    )..where((t) => t.id.isIn(unique))).get();
    final media = await (_db.select(
      _db.mediaItems,
    )..where((t) => t.id.isIn(unique))).get();
    final thingById = {for (final t in things) t.id: t};
    final mediaById = {for (final m in media) m.id: m};

    final out = <HydratedNode>[];
    for (final id in ids) {
      final thing = thingById[id];
      final item = mediaById[id];
      if (thing == null && item == null) continue;
      out.add(
        HydratedNode(
          id: id,
          title: thing?.name ?? item?.title ?? id,
          type: thing?.type,
          media: item,
        ),
      );
    }
    return out;
  }
}

final nodeHydrationProvider = Provider<NodeHydration>(
  (ref) => NodeHydration(ref.watch(appDatabaseProvider)),
);
