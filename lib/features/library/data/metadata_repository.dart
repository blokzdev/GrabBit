import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';

enum LibrarySort { newest, oldest, titleAsc, largest }

/// Search / filter / sort parameters for the library grid.
class LibraryQuery {
  const LibraryQuery({
    this.search = '',
    this.type,
    this.collectionId,
    this.sort = LibrarySort.newest,
  });

  final String search;
  final String? type; // video | audio | image | null (all)
  final int? collectionId;
  final LibrarySort sort;

  LibraryQuery copyWith({
    String? search,
    String? Function()? type,
    int? Function()? collectionId,
    LibrarySort? sort,
  }) => LibraryQuery(
    search: search ?? this.search,
    type: type != null ? type() : this.type,
    collectionId: collectionId != null ? collectionId() : this.collectionId,
    sort: sort ?? this.sort,
  );
}

/// Tags, collections, notes/title edits, and parameterized library queries.
class MetadataRepository {
  MetadataRepository(this._db);

  final AppDatabase _db;

  Stream<List<MediaItem>> watchFiltered(LibraryQuery q) {
    final query = _db.select(_db.mediaItems);
    if (q.search.trim().isNotEmpty) {
      query.where((t) => t.title.like('%${q.search.trim()}%'));
    }
    if (q.type != null) {
      query.where((t) => t.type.equals(q.type!));
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
    query.orderBy([
      switch (q.sort) {
        LibrarySort.newest => (t) => OrderingTerm.desc(t.createdAt),
        LibrarySort.oldest => (t) => OrderingTerm.asc(t.createdAt),
        LibrarySort.titleAsc => (t) => OrderingTerm.asc(t.title),
        LibrarySort.largest => (t) => OrderingTerm.desc(t.sizeBytes),
      },
    ]);
    return query.watch();
  }

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

final collectionsForItemProvider =
    StreamProvider.family<List<Collection>, String>(
      (ref, itemId) =>
          ref.watch(metadataRepositoryProvider).watchCollectionsForItem(itemId),
    );

final collectionItemsProvider = StreamProvider.family<List<MediaItem>, int>(
  (ref, collectionId) => ref
      .watch(metadataRepositoryProvider)
      .watchFiltered(LibraryQuery(collectionId: collectionId)),
);
