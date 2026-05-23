import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';

void main() {
  late AppDatabase db;
  late MetadataRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = MetadataRepository(db);
  });
  tearDown(() => db.close());

  Future<void> seed(
    String id,
    String title,
    String type, {
    int day = 1,
    int size = 100,
    String site = 'youtube',
  }) => db
      .into(db.mediaItems)
      .insert(
        MediaItemsCompanion.insert(
          id: id,
          title: title,
          sourceUrl: 'https://y/$id',
          site: site,
          filePath: '/m/$id',
          type: type,
          createdAt: DateTime.utc(2026, 1, day),
          storageState: 'private',
          sizeBytes: Value(size),
        ),
      );

  Future<void> seedMeta(
    String itemId, {
    String? uploader,
    String? description,
    String? playlistId,
    String? playlistTitle,
  }) => db
      .into(db.mediaMetadata)
      .insert(
        MediaMetadataCompanion.insert(
          itemId: itemId,
          uploader: Value(uploader),
          description: Value(description),
          playlistId: Value(playlistId),
          playlistTitle: Value(playlistTitle),
        ),
      );

  test('search filters by title (case-insensitive)', () async {
    await seed('a', 'Cats compilation', 'video');
    await seed('b', 'Dogs', 'video');
    final rows = await repo
        .watchFiltered(const LibraryQuery(search: 'cat'))
        .first;
    expect(rows.map((r) => r.id), ['a']);
  });

  test('filters by type and sorts by title', () async {
    await seed('a', 'Beta', 'video');
    await seed('b', 'Song', 'audio');
    await seed('c', 'Alpha', 'video');
    final rows = await repo
        .watchFiltered(
          const LibraryQuery(type: 'video', sort: LibrarySort.titleAsc),
        )
        .first;
    expect(rows.map((r) => r.id), ['c', 'a']);
  });

  test('sorts by largest size', () async {
    await seed('a', 'A', 'video', size: 10);
    await seed('b', 'B', 'video', size: 99);
    final rows = await repo
        .watchFiltered(const LibraryQuery(sort: LibrarySort.largest))
        .first;
    expect(rows.first.id, 'b');
  });

  test('sorts by smallest size', () async {
    await seed('a', 'A', 'video', size: 10);
    await seed('b', 'B', 'video', size: 99);
    final rows = await repo
        .watchFiltered(const LibraryQuery(sort: LibrarySort.smallest))
        .first;
    expect(rows.first.id, 'a');
  });

  test('toggleFavorite persists and favoritesOnly filters', () async {
    await seed('a', 'A', 'video');
    await seed('b', 'B', 'video');
    await repo.toggleFavorite('a', true);
    final favs = await repo
        .watchFiltered(const LibraryQuery(favoritesOnly: true))
        .first;
    expect(favs.map((r) => r.id), ['a']);

    await repo.toggleFavorite('a', false);
    final none = await repo
        .watchFiltered(const LibraryQuery(favoritesOnly: true))
        .first;
    expect(none, isEmpty);
  });

  test('recentlyPlayed sorts by lastAccessedAt, nulls last', () async {
    await seed('a', 'A', 'video');
    await seed('b', 'B', 'video');
    // Only 'b' has been played.
    await (db.update(db.mediaItems)..where((t) => t.id.equals('b'))).write(
      MediaItemsCompanion(lastAccessedAt: Value(DateTime.utc(2026, 5, 23))),
    );
    final rows = await repo
        .watchFiltered(const LibraryQuery(sort: LibrarySort.recentlyPlayed))
        .first;
    expect(rows.map((r) => r.id), ['b', 'a']);
  });

  test('tags: add, list, remove', () async {
    await seed('a', 'A', 'video');
    await repo.addTagToItem('a', 'funny');
    await repo.addTagToItem('a', 'funny'); // idempotent
    await repo.addTagToItem('a', 'pets');
    var tags = await repo.watchTagsForItem('a').first;
    expect(tags.map((t) => t.name).toSet(), {'funny', 'pets'});

    await repo.removeTagFromItem(
      'a',
      tags.firstWhere((t) => t.name == 'funny').id,
    );
    tags = await repo.watchTagsForItem('a').first;
    expect(tags.map((t) => t.name), ['pets']);
  });

  test('collections: create, add item, filter, remove', () async {
    await seed('a', 'A', 'video');
    await seed('b', 'B', 'video');
    final cId = await repo.createCollection('Faves');

    await repo.addItemToCollection('a', cId);
    final inCollection = await repo
        .watchFiltered(LibraryQuery(collectionId: cId))
        .first;
    expect(inCollection.map((r) => r.id), ['a']);

    final memberships = await repo.watchCollectionsForItem('a').first;
    expect(memberships.single.name, 'Faves');

    await repo.removeItemFromCollection('a', cId);
    expect(
      await repo.watchFiltered(LibraryQuery(collectionId: cId)).first,
      isEmpty,
    );
  });

  test('watchMetadataForItem emits the row, null when absent', () async {
    await seed('a', 'A', 'video');
    expect(await repo.watchMetadataForItem('a').first, isNull);

    await db
        .into(db.mediaMetadata)
        .insert(
          MediaMetadataCompanion.insert(
            itemId: 'a',
            uploader: const Value('Chan'),
            description: const Value('A clip'),
            uploadDate: Value(DateTime.utc(2024, 1, 15)),
          ),
        );
    final meta = await repo.watchMetadataForItem('a').first;
    expect(meta, isNotNull);
    expect(meta!.uploader, 'Chan');
    expect(meta.description, 'A clip');
  });

  test('updateTitle and updateNotes', () async {
    await seed('a', 'Old', 'video');
    await repo.updateTitle('a', 'New title');
    await repo.updateNotes('a', 'a note');
    final item = await (db.select(
      db.mediaItems,
    )..where((t) => t.id.equals('a'))).getSingle();
    expect(item.title, 'New title');
    expect(item.notes, 'a note');
  });

  group('facets', () {
    test('search also matches the description', () async {
      await seed('a', 'Untitled', 'video');
      await seed('b', 'Other', 'video');
      await seedMeta('a', description: 'a rare keyword here');
      final rows = await repo
          .watchFiltered(const LibraryQuery(search: 'rare keyword'))
          .first;
      expect(rows.map((r) => r.id), ['a']);
    });

    test('filters by site (platform)', () async {
      await seed('a', 'A', 'video', site: 'youtube');
      await seed('b', 'B', 'video', site: 'tiktok');
      final rows = await repo
          .watchFiltered(const LibraryQuery(site: 'tiktok'))
          .first;
      expect(rows.map((r) => r.id), ['b']);
    });

    test('filters by uploader (channel)', () async {
      await seed('a', 'A', 'video');
      await seed('b', 'B', 'video');
      await seedMeta('a', uploader: 'Rick');
      await seedMeta('b', uploader: 'Other');
      final rows = await repo
          .watchFiltered(const LibraryQuery(uploader: 'Rick'))
          .first;
      expect(rows.map((r) => r.id), ['a']);
    });

    test('filters by playlist', () async {
      await seed('a', 'A', 'video');
      await seed('b', 'B', 'video');
      await seedMeta('a', playlistId: 'PL1', playlistTitle: 'Mix');
      final rows = await repo
          .watchFiltered(const LibraryQuery(playlistId: 'PL1'))
          .first;
      expect(rows.map((r) => r.id), ['a']);
    });

    test('distinct facet values', () async {
      await seed('a', 'A', 'video', site: 'youtube');
      await seed('b', 'B', 'video', site: 'tiktok');
      await seedMeta(
        'a',
        uploader: 'Rick',
        playlistId: 'PL1',
        playlistTitle: 'Mix',
      );
      await seedMeta('b', uploader: 'Rick'); // duplicate uploader

      expect(await repo.watchDistinctSites().first, ['tiktok', 'youtube']);
      expect(await repo.watchDistinctUploaders().first, ['Rick']);
      final playlists = await repo.watchDistinctPlaylists().first;
      expect(playlists.map((p) => p.id), ['PL1']);
      expect(playlists.single.title, 'Mix');
    });
  });
}
