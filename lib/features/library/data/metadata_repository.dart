import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/utils/shared_url.dart';

enum LibrarySort {
  newest,
  oldest,
  titleAsc,
  titleDesc,
  largest,
  smallest,
  recentlyPlayed,
}

/// Search / filter / sort parameters for the library grid.
class LibraryQuery {
  const LibraryQuery({
    this.search = '',
    this.type,
    this.collectionId,
    this.sort = LibrarySort.newest,
    this.site,
    this.uploader,
    this.playlistId,
    this.favoritesOnly = false,
  });

  final String search; // matches title OR description
  final String? type; // video | audio | image | null (all)
  final int? collectionId;
  final LibrarySort sort;
  final String? site; // platform facet
  final String? uploader; // channel facet
  final String? playlistId; // playlist facet
  final bool favoritesOnly;

  /// Active metadata facets (excludes search/type/sort/collection).
  int get activeFacetCount =>
      (site != null ? 1 : 0) +
      (uploader != null ? 1 : 0) +
      (playlistId != null ? 1 : 0);

  LibraryQuery copyWith({
    String? search,
    String? Function()? type,
    int? Function()? collectionId,
    LibrarySort? sort,
    String? Function()? site,
    String? Function()? uploader,
    String? Function()? playlistId,
    bool? favoritesOnly,
  }) => LibraryQuery(
    search: search ?? this.search,
    type: type != null ? type() : this.type,
    collectionId: collectionId != null ? collectionId() : this.collectionId,
    sort: sort ?? this.sort,
    site: site != null ? site() : this.site,
    uploader: uploader != null ? uploader() : this.uploader,
    playlistId: playlistId != null ? playlistId() : this.playlistId,
    favoritesOnly: favoritesOnly ?? this.favoritesOnly,
  );
}

/// A distinct playlist facet value (filter by [id], display [title]).
class PlaylistFacet {
  const PlaylistFacet({required this.id, required this.title});
  final String id;
  final String title;
}

/// Tags, collections, notes/title edits, and parameterized library queries.
class MetadataRepository {
  MetadataRepository(this._db);

  final AppDatabase _db;

  Stream<List<MediaItem>> watchFiltered(LibraryQuery q) {
    final query = _db.select(_db.mediaItems);
    final search = q.search.trim();
    if (search.isNotEmpty) {
      // Match the title OR the description (via the metadata table).
      query.where(
        (t) =>
            t.title.like('%$search%') |
            t.id.isInQuery(
              _db.selectOnly(_db.mediaMetadata)
                ..addColumns([_db.mediaMetadata.itemId])
                ..where(_db.mediaMetadata.description.like('%$search%')),
            ),
      );
    }
    if (q.type != null) {
      query.where((t) => t.type.equals(q.type!));
    }
    if (q.site != null) {
      query.where((t) => t.site.equals(q.site!));
    }
    if (q.favoritesOnly) {
      query.where((t) => t.isFavorite.equals(true));
    }
    if (q.collectionId != null) {
      query.where(
        (t) => t.id.isInQuery(
          _db.selectOnly(_db.mediaCollections)
            ..addColumns([_db.mediaCollections.itemId])
            ..where(_db.mediaCollections.collectionId.equals(q.collectionId!)),
        ),
      );
    }
    if (q.uploader != null) {
      query.where(
        (t) => t.id.isInQuery(
          _db.selectOnly(_db.mediaMetadata)
            ..addColumns([_db.mediaMetadata.itemId])
            ..where(_db.mediaMetadata.uploader.equals(q.uploader!)),
        ),
      );
    }
    if (q.playlistId != null) {
      query.where(
        (t) => t.id.isInQuery(
          _db.selectOnly(_db.mediaMetadata)
            ..addColumns([_db.mediaMetadata.itemId])
            ..where(_db.mediaMetadata.playlistId.equals(q.playlistId!)),
        ),
      );
    }
    query.orderBy([
      switch (q.sort) {
        LibrarySort.newest => (t) => OrderingTerm.desc(t.createdAt),
        LibrarySort.oldest => (t) => OrderingTerm.asc(t.createdAt),
        LibrarySort.titleAsc => (t) => OrderingTerm.asc(t.title),
        LibrarySort.titleDesc => (t) => OrderingTerm.desc(t.title),
        LibrarySort.largest => (t) => OrderingTerm.desc(t.sizeBytes),
        LibrarySort.smallest => (t) => OrderingTerm.asc(t.sizeBytes),
        // NULLs (never played) sort last on DESC in SQLite.
        LibrarySort.recentlyPlayed => (t) => OrderingTerm.desc(
          t.lastAccessedAt,
        ),
      },
    ]);
    return query.watch();
  }

  /// Stars or unstars a library item (P9b).
  Future<void> toggleFavorite(String itemId, bool value) async {
    await (_db.update(_db.mediaItems)..where((t) => t.id.equals(itemId))).write(
      MediaItemsCompanion(isFavorite: Value(value)),
    );
  }

  /// Stamps `lastAccessedAt` = now (P9c); feeds the "Recently played" album.
  Future<void> markPlayed(String itemId) async {
    await (_db.update(_db.mediaItems)..where((t) => t.id.equals(itemId))).write(
      MediaItemsCompanion(lastAccessedAt: Value(DateTime.now())),
    );
  }

  /// Distinct platform/site values present in the library (for the facet picker).
  Stream<List<String>> watchDistinctSites() {
    final q = _db.selectOnly(_db.mediaItems, distinct: true)
      ..addColumns([_db.mediaItems.site])
      ..orderBy([OrderingTerm.asc(_db.mediaItems.site)]);
    return q.map((r) => r.read(_db.mediaItems.site)!).watch();
  }

  /// Distinct uploader/channel names present in the library.
  Stream<List<String>> watchDistinctUploaders() {
    final q = _db.selectOnly(_db.mediaMetadata, distinct: true)
      ..addColumns([_db.mediaMetadata.uploader])
      ..where(_db.mediaMetadata.uploader.isNotNull())
      ..orderBy([OrderingTerm.asc(_db.mediaMetadata.uploader)]);
    return q.map((r) => r.read(_db.mediaMetadata.uploader)!).watch();
  }

  /// Distinct playlists present in the library.
  Stream<List<PlaylistFacet>> watchDistinctPlaylists() {
    final q = _db.selectOnly(_db.mediaMetadata, distinct: true)
      ..addColumns([
        _db.mediaMetadata.playlistId,
        _db.mediaMetadata.playlistTitle,
      ])
      ..where(_db.mediaMetadata.playlistId.isNotNull())
      ..orderBy([OrderingTerm.asc(_db.mediaMetadata.playlistTitle)]);
    return q.map((r) {
      final id = r.read(_db.mediaMetadata.playlistId)!;
      return PlaylistFacet(
        id: id,
        title: r.read(_db.mediaMetadata.playlistTitle) ?? id,
      );
    }).watch();
  }

  // --- Smart / auto albums (P9b-2) ---

  /// Item counts per platform (`site` → count), for the Platforms albums.
  Stream<Map<String, int>> watchItemCountsBySite() {
    final count = _db.mediaItems.id.count();
    final query = _db.selectOnly(_db.mediaItems)
      ..addColumns([_db.mediaItems.site, count])
      ..groupBy([_db.mediaItems.site]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(_db.mediaItems.site)!: row.read(count) ?? 0,
      },
    );
  }

  /// Item counts per channel (`uploader` → count), for the Channels albums.
  Stream<Map<String, int>> watchItemCountsByUploader() {
    final count = _db.mediaMetadata.itemId.count();
    final query = _db.selectOnly(_db.mediaMetadata)
      ..addColumns([_db.mediaMetadata.uploader, count])
      ..where(_db.mediaMetadata.uploader.isNotNull())
      ..groupBy([_db.mediaMetadata.uploader]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(_db.mediaMetadata.uploader)!: row.read(count) ?? 0,
      },
    );
  }

  /// Items played at least once, most-recent first (the Recently-played album).
  Stream<List<MediaItem>> watchRecentlyPlayed({int limit = 100}) {
    final query = _db.select(_db.mediaItems)
      ..where((t) => t.lastAccessedAt.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.lastAccessedAt)])
      ..limit(limit);
    return query.watch();
  }

  // --- Preventive (source-identity) dedupe (P9b-4) ---

  /// The library item with this yt-dlp source id, or null. Used to warn before
  /// re-downloading something already saved.
  Future<MediaItem?> findItemBySourceId(String sourceId) async {
    final rows = await (_db.select(_db.mediaItems).join([
      innerJoin(
        _db.mediaMetadata,
        _db.mediaMetadata.itemId.equalsExp(_db.mediaItems.id),
      ),
    ])..where(_db.mediaMetadata.sourceId.equals(sourceId))).get();
    return rows.isEmpty ? null : rows.first.readTable(_db.mediaItems);
  }

  /// Fallback match by source URL (tracking params stripped), for items saved
  /// without a source id.
  Future<MediaItem?> findItemByUrl(String url) async {
    final normalized = stripTrackingParams(url);
    final rows =
        await (_db.select(_db.mediaItems)
              ..where((t) => t.sourceUrl.equals(normalized))
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// All source ids present in the library (one-shot), for marking playlist
  /// entries already saved.
  Future<Set<String>> existingSourceIds() async {
    final q = _db.selectOnly(_db.mediaMetadata)
      ..addColumns([_db.mediaMetadata.sourceId])
      ..where(_db.mediaMetadata.sourceId.isNotNull());
    final rows = await q.get();
    return {for (final r in rows) r.read(_db.mediaMetadata.sourceId)!};
  }

  // --- Duplicates & storage (P9b-3) ---

  /// Groups of items that share a `contentHash` (2+ each) — likely duplicates.
  Stream<List<List<MediaItem>>> watchDuplicates() {
    final query = _db.select(_db.mediaItems)
      ..where((t) => t.contentHash.isNotNull())
      ..orderBy([
        (t) => OrderingTerm.asc(t.contentHash),
        (t) => OrderingTerm.asc(t.createdAt),
      ]);
    return query.watch().map((rows) {
      final groups = <String, List<MediaItem>>{};
      for (final r in rows) {
        groups.putIfAbsent(r.contentHash!, () => []).add(r);
      }
      return groups.values.where((g) => g.length > 1).toList();
    });
  }

  /// Total bytes per media type (`video`/`audio`/`image`).
  Stream<Map<String, int>> watchSizeByType() =>
      _watchSizeGrouped(_db.mediaItems.type);

  /// Total bytes per platform (`site`).
  Stream<Map<String, int>> watchSizeBySite() =>
      _watchSizeGrouped(_db.mediaItems.site);

  Stream<Map<String, int>> _watchSizeGrouped(GeneratedColumn<String> column) {
    final sum = _db.mediaItems.sizeBytes.sum();
    final query = _db.selectOnly(_db.mediaItems)
      ..addColumns([column, sum])
      ..groupBy([column]);
    return query.watch().map(
      (rows) => {
        for (final row in rows) row.read<String>(column)!: row.read(sum) ?? 0,
      },
    );
  }

  /// The biggest items first (for storage cleanup).
  Stream<List<MediaItem>> watchLargestItems({int limit = 20}) {
    final query = _db.select(_db.mediaItems)
      ..where((t) => t.sizeBytes.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.sizeBytes)])
      ..limit(limit);
    return query.watch();
  }

  Stream<MediaMetadataData?> watchMetadataForItem(String itemId) => (_db.select(
    _db.mediaMetadata,
  )..where((t) => t.itemId.equals(itemId))).watchSingleOrNull();

  Future<void> updateTitle(String itemId, String title) async {
    await (_db.update(_db.mediaItems)..where((t) => t.id.equals(itemId))).write(
      MediaItemsCompanion(title: Value(title.trim())),
    );
  }

  Future<void> updateNotes(String itemId, String? notes) async {
    await (_db.update(_db.mediaItems)..where((t) => t.id.equals(itemId))).write(
      MediaItemsCompanion(notes: Value(notes)),
    );
  }

  // --- Tags ---

  Stream<List<Tag>> watchTagsForItem(String itemId) {
    final query = _db.select(_db.tags).join([
      innerJoin(_db.mediaTags, _db.mediaTags.tagId.equalsExp(_db.tags.id)),
    ])..where(_db.mediaTags.itemId.equals(itemId));
    return query.map((row) => row.readTable(_db.tags)).watch();
  }

  Future<void> addTagToItem(String itemId, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    await _db
        .into(_db.tags)
        .insert(
          TagsCompanion.insert(name: clean),
          mode: InsertMode.insertOrIgnore,
        );
    final tag = await (_db.select(
      _db.tags,
    )..where((t) => t.name.equals(clean))).getSingle();
    await _db
        .into(_db.mediaTags)
        .insert(
          MediaTagsCompanion.insert(itemId: itemId, tagId: tag.id),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> removeTagFromItem(String itemId, int tagId) async {
    await (_db.delete(
      _db.mediaTags,
    )..where((t) => t.itemId.equals(itemId) & t.tagId.equals(tagId))).go();
  }

  // --- Collections ---

  Stream<List<Collection>> watchCollections() => (_db.select(
    _db.collections,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<int> createCollection(String name) => _db
      .into(_db.collections)
      .insert(
        CollectionsCompanion.insert(
          name: name.trim(),
          createdAt: DateTime.now(),
        ),
      );

  Future<void> deleteCollection(int id) async {
    await (_db.delete(_db.collections)..where((t) => t.id.equals(id))).go();
  }

  Future<void> renameCollection(int id, String name) async {
    await (_db.update(_db.collections)..where((t) => t.id.equals(id))).write(
      CollectionsCompanion(name: Value(name.trim())),
    );
  }

  /// Item counts per collection (`collectionId` → count) for the list rows.
  Stream<Map<int, int>> watchCollectionItemCounts() {
    final count = _db.mediaCollections.itemId.count();
    final query = _db.selectOnly(_db.mediaCollections)
      ..addColumns([_db.mediaCollections.collectionId, count])
      ..groupBy([_db.mediaCollections.collectionId]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(_db.mediaCollections.collectionId)!: row.read(count) ?? 0,
      },
    );
  }

  Stream<List<Collection>> watchCollectionsForItem(String itemId) {
    final query = _db.select(_db.collections).join([
      innerJoin(
        _db.mediaCollections,
        _db.mediaCollections.collectionId.equalsExp(_db.collections.id),
      ),
    ])..where(_db.mediaCollections.itemId.equals(itemId));
    return query.map((row) => row.readTable(_db.collections)).watch();
  }

  Future<void> addItemToCollection(String itemId, int collectionId) async {
    await _db
        .into(_db.mediaCollections)
        .insert(
          MediaCollectionsCompanion.insert(
            itemId: itemId,
            collectionId: collectionId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> removeItemFromCollection(String itemId, int collectionId) async {
    await (_db.delete(_db.mediaCollections)..where(
          (t) => t.itemId.equals(itemId) & t.collectionId.equals(collectionId),
        ))
        .go();
  }
}

final metadataRepositoryProvider = Provider<MetadataRepository>(
  (ref) => MetadataRepository(ref.watch(appDatabaseProvider)),
);

final tagsForItemProvider = StreamProvider.family<List<Tag>, String>(
  (ref, itemId) =>
      ref.watch(metadataRepositoryProvider).watchTagsForItem(itemId),
);

final collectionsProvider = StreamProvider<List<Collection>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchCollections(),
);

final collectionItemCountsProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchCollectionItemCounts(),
);

final collectionsForItemProvider =
    StreamProvider.family<List<Collection>, String>(
      (ref, itemId) =>
          ref.watch(metadataRepositoryProvider).watchCollectionsForItem(itemId),
    );

// Hand-written (returns a Drift row type) per CLAUDE.md §8.
final metadataForItemProvider =
    StreamProvider.family<MediaMetadataData?, String>(
      (ref, itemId) =>
          ref.watch(metadataRepositoryProvider).watchMetadataForItem(itemId),
    );

final collectionItemsProvider = StreamProvider.family<List<MediaItem>, int>(
  (ref, collectionId) => ref
      .watch(metadataRepositoryProvider)
      .watchFiltered(LibraryQuery(collectionId: collectionId)),
);

// Distinct facet values for the Library filter sheet.
final distinctSitesProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchDistinctSites(),
);

final distinctUploadersProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchDistinctUploaders(),
);

final distinctPlaylistsProvider = StreamProvider<List<PlaylistFacet>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchDistinctPlaylists(),
);

// Smart / auto albums (P9b-2).
final siteCountsProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchItemCountsBySite(),
);

final uploaderCountsProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchItemCountsByUploader(),
);

final recentlyPlayedProvider = StreamProvider<List<MediaItem>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchRecentlyPlayed(),
);

// Duplicates & storage (P9b-3).
final duplicatesProvider = StreamProvider<List<List<MediaItem>>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchDuplicates(),
);

final sizeByTypeProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchSizeByType(),
);

final sizeBySiteProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchSizeBySite(),
);

final largestItemsProvider = StreamProvider<List<MediaItem>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchLargestItems(),
);

/// Items for a smart album, keyed by ([kind], [value]). `kind` is
/// `site` | `channel` | `recentPlayed`.
final smartAlbumItemsProvider =
    StreamProvider.family<List<MediaItem>, ({String kind, String? value})>((
      ref,
      key,
    ) {
      final repo = ref.watch(metadataRepositoryProvider);
      return switch (key.kind) {
        'site' => repo.watchFiltered(LibraryQuery(site: key.value)),
        'channel' => repo.watchFiltered(LibraryQuery(uploader: key.value)),
        _ => repo.watchRecentlyPlayed(),
      };
    });
