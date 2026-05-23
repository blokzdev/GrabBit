import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';

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
