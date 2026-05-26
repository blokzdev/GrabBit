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
    int? durationSec,
    int? height,
    DateTime? createdAt,
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
          createdAt: createdAt ?? DateTime.utc(2026, 1, day),
          storageState: 'private',
          sizeBytes: Value(size),
          durationSec: Value(durationSec),
          height: Value(height),
        ),
      );

  Future<void> seedMeta(
    String itemId, {
    String? uploader,
    String? description,
    String? playlistId,
    String? playlistTitle,
    String? transcript,
    DateTime? uploadDate,
  }) => db
      .into(db.mediaMetadata)
      .insert(
        MediaMetadataCompanion.insert(
          itemId: itemId,
          uploader: Value(uploader),
          description: Value(description),
          playlistId: Value(playlistId),
          playlistTitle: Value(playlistTitle),
          transcript: Value(transcript),
          uploadDate: Value(uploadDate),
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
          const LibraryQuery(types: {'video'}, sort: LibrarySort.titleAsc),
        )
        .first;
    expect(rows.map((r) => r.id), ['c', 'a']);
  });

  test(
    'multi-select type filter returns the union of selected types',
    () async {
      await seed('a', 'Vid', 'video');
      await seed('b', 'Song', 'audio');
      await seed('c', 'Pic', 'image');
      final rows = await repo
          .watchFiltered(
            const LibraryQuery(
              types: {'video', 'audio'},
              sort: LibrarySort.oldest,
            ),
          )
          .first;
      expect(rows.map((r) => r.id), ['a', 'b']);
    },
  );

  test('empty type set returns all types', () async {
    await seed('a', 'Vid', 'video');
    await seed('b', 'Pic', 'image');
    final rows = await repo.watchFiltered(const LibraryQuery()).first;
    expect(rows.map((r) => r.id).toSet(), {'a', 'b'});
  });

  test('search path honours a multi-type filter', () async {
    await seed('a', 'Cats video', 'video');
    await seed('b', 'Cats song', 'audio');
    await seed('c', 'Cats pic', 'image');
    final rows = await repo
        .watchFiltered(const LibraryQuery(search: 'cats', types: {'image'}))
        .first;
    expect(rows.map((r) => r.id), ['c']);
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

  test('duration sorts order by length with null durations last', () async {
    await seed('short', 'S', 'video', durationSec: 30);
    await seed('long', 'L', 'video', durationSec: 600);
    await seed('none', 'N', 'video'); // null duration (e.g. split-chapter)

    final longest = await repo
        .watchFiltered(const LibraryQuery(sort: LibrarySort.longest))
        .first;
    expect(longest.map((r) => r.id), ['long', 'short', 'none']);

    final shortest = await repo
        .watchFiltered(const LibraryQuery(sort: LibrarySort.shortest))
        .first;
    expect(shortest.map((r) => r.id), ['short', 'long', 'none']);
  });

  test('upload-date sorts order by metadata date with nulls last', () async {
    await seed('old', 'O', 'video');
    await seed('new', 'N', 'video');
    await seed('undated', 'U', 'video'); // no metadata row → null upload date
    await seedMeta('old', uploadDate: DateTime.utc(2020, 1, 1));
    await seedMeta('new', uploadDate: DateTime.utc(2024, 6, 1));

    final newest = await repo
        .watchFiltered(const LibraryQuery(sort: LibrarySort.uploadNewest))
        .first;
    expect(newest.map((r) => r.id), ['new', 'old', 'undated']);

    final oldest = await repo
        .watchFiltered(const LibraryQuery(sort: LibrarySort.uploadOldest))
        .first;
    expect(oldest.map((r) => r.id), ['old', 'new', 'undated']);
  });

  test('new sorts also apply on the search path', () async {
    await seed('short', 'clip short', 'video', durationSec: 30);
    await seed('long', 'clip long', 'video', durationSec: 600);
    await seedMeta('short', uploadDate: DateTime.utc(2024, 1, 1));
    await seedMeta('long', uploadDate: DateTime.utc(2020, 1, 1));

    final byLongest = await repo
        .watchFiltered(
          const LibraryQuery(search: 'clip', sort: LibrarySort.longest),
        )
        .first;
    expect(byLongest.map((r) => r.id), ['long', 'short']);

    final byUploadNewest = await repo
        .watchFiltered(
          const LibraryQuery(search: 'clip', sort: LibrarySort.uploadNewest),
        )
        .first;
    expect(byUploadNewest.map((r) => r.id), ['short', 'long']);
  });

  group('P10i-d range buckets', () {
    test('duration bucket narrows and excludes unknown durations', () async {
      await seed('s', 'clip s', 'video', durationSec: 30);
      await seed('m', 'clip m', 'video', durationSec: 180); // 3 min
      await seed('n', 'clip n', 'video'); // null duration

      for (final q in [
        const LibraryQuery(durationBucket: DurationBucket.oneToFive),
        const LibraryQuery(
          search: 'clip',
          durationBucket: DurationBucket.oneToFive,
        ),
      ]) {
        final rows = await repo.watchFiltered(q).first;
        expect(rows.map((r) => r.id), ['m'], reason: '$q');
      }
    });

    test('resolution bucket narrows by height, excludes unknown', () async {
      await seed('sd', 'clip sd', 'video', height: 480);
      await seed('hd', 'clip hd', 'video', height: 1080);
      await seed('uhd', 'clip uhd', 'video', height: 2160);
      await seed('none', 'clip none', 'video'); // null height

      for (final q in [
        const LibraryQuery(resolutionBucket: ResolutionBucket.fullHd),
        const LibraryQuery(
          search: 'clip',
          resolutionBucket: ResolutionBucket.fullHd,
        ),
      ]) {
        final rows = await repo.watchFiltered(q).first;
        expect(rows.map((r) => r.id), ['hd'], reason: '$q');
      }
    });

    test('downloaded bucket filters by created_at', () async {
      final now = DateTime.now();
      await seed('recent', 'Recent', 'video', createdAt: now);
      await seed(
        'old',
        'Old',
        'video',
        createdAt: now.subtract(const Duration(days: 400)),
      );

      final rows = await repo
          .watchFiltered(const LibraryQuery(downloadedBucket: DateBucket.last7))
          .first;
      expect(rows.map((r) => r.id), ['recent']);
    });

    test('uploaded bucket filters by upload_date, excludes unknown', () async {
      final now = DateTime.now();
      await seed('recent', 'clip recent', 'video');
      await seed('old', 'clip old', 'video');
      await seed('undated', 'clip undated', 'video');
      await seedMeta(
        'recent',
        uploadDate: now.subtract(const Duration(days: 2)),
      );
      await seedMeta(
        'old',
        uploadDate: now.subtract(const Duration(days: 400)),
      );

      for (final q in [
        const LibraryQuery(uploadedBucket: DateBucket.last30),
        const LibraryQuery(search: 'clip', uploadedBucket: DateBucket.last30),
      ]) {
        final rows = await repo.watchFiltered(q).first;
        expect(rows.map((r) => r.id), ['recent'], reason: '$q');
      }
    });
  });

  group('bucket range mappings', () {
    test('duration ranges are contiguous seconds', () {
      expect(DurationBucket.underMin.range, (0, 60));
      expect(DurationBucket.twentyToHour.range, (1200, 3600));
      expect(DurationBucket.overHour.range, (3600, null));
    });

    test('resolution ranges are contiguous heights', () {
      expect(ResolutionBucket.sd.heightRange, (0, 720));
      expect(ResolutionBucket.uhd.heightRange, (2160, null));
    });

    test('date buckets resolve relative to now', () {
      final now = DateTime(2026, 5, 26, 14, 30);
      expect(DateBucket.today.since(now), DateTime(2026, 5, 26));
      expect(
        DateBucket.last7.since(now),
        now.subtract(const Duration(days: 7)),
      );
      expect(DateBucket.thisYear.since(now), DateTime(2026));
    });
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

  test('watchItemCountsBySite groups by platform', () async {
    await seed('a', 'A', 'video', site: 'youtube');
    await seed('b', 'B', 'video', site: 'youtube');
    await seed('c', 'C', 'video', site: 'vimeo');
    final counts = await repo.watchItemCountsBySite().first;
    expect(counts, {'youtube': 2, 'vimeo': 1});
  });

  test('watchItemCountsByUploader groups by channel', () async {
    await seed('a', 'A', 'video');
    await seed('b', 'B', 'video');
    await seedMeta('a', uploader: 'Rick');
    await seedMeta('b', uploader: 'Rick');
    final counts = await repo.watchItemCountsByUploader().first;
    expect(counts, {'Rick': 2});
  });

  test('watchRecentlyPlayed returns only played items, newest first', () async {
    await seed('a', 'A', 'video');
    await seed('b', 'B', 'video');
    await seed('c', 'C', 'video'); // never played
    await (db.update(db.mediaItems)..where((t) => t.id.equals('a'))).write(
      MediaItemsCompanion(lastAccessedAt: Value(DateTime.utc(2026, 5, 1))),
    );
    await (db.update(db.mediaItems)..where((t) => t.id.equals('b'))).write(
      MediaItemsCompanion(lastAccessedAt: Value(DateTime.utc(2026, 5, 9))),
    );
    final rows = await repo.watchRecentlyPlayed().first;
    expect(rows.map((r) => r.id), ['b', 'a']);

    final limited = await repo.watchRecentlyPlayed(limit: 1).first;
    expect(limited.map((r) => r.id), ['b']);
  });

  test('watchDuplicates groups items sharing a content hash', () async {
    await seed('a', 'A', 'video');
    await seed('b', 'B', 'video');
    await seed('c', 'C', 'video');
    Future<void> setHash(String id, String h) =>
        (db.update(db.mediaItems)..where((t) => t.id.equals(id))).write(
          MediaItemsCompanion(contentHash: Value(h)),
        );
    await setHash('a', 'dup');
    await setHash('b', 'dup');
    await setHash('c', 'unique');

    final groups = await repo.watchDuplicates().first;
    expect(groups, hasLength(1));
    expect(groups.single.map((r) => r.id).toSet(), {'a', 'b'});
  });

  test('watchSizeByType and watchSizeBySite sum sizes', () async {
    await seed('a', 'A', 'video', size: 100, site: 'youtube');
    await seed('b', 'B', 'video', size: 50, site: 'vimeo');
    await seed('c', 'C', 'audio', size: 20, site: 'youtube');

    expect(await repo.watchSizeByType().first, {'video': 150, 'audio': 20});
    expect(await repo.watchSizeBySite().first, {'youtube': 120, 'vimeo': 50});
  });

  test('watchLargestItems orders by size desc and limits', () async {
    await seed('a', 'A', 'video', size: 10);
    await seed('b', 'B', 'video', size: 99);
    await seed('c', 'C', 'video', size: 50);
    final rows = await repo.watchLargestItems(limit: 2).first;
    expect(rows.map((r) => r.id), ['b', 'c']);
  });

  test('findItemBySourceId + existingSourceIds (P9b-4)', () async {
    await seed('a', 'A', 'video');
    await db
        .into(db.mediaMetadata)
        .insert(
          MediaMetadataCompanion.insert(
            itemId: 'a',
            sourceId: const Value('vid123'),
          ),
        );

    final hit = await repo.findItemBySourceId('vid123');
    expect(hit?.id, 'a');
    expect(await repo.findItemBySourceId('nope'), isNull);
    expect(await repo.existingSourceIds(), {'vid123'});
  });

  test('markPlayed stamps lastAccessedAt and feeds recently played', () async {
    await seed('a', 'A', 'video');
    expect((await repo.watchRecentlyPlayed().first), isEmpty);

    await repo.markPlayed('a');

    final item = await (db.select(
      db.mediaItems,
    )..where((t) => t.id.equals('a'))).getSingle();
    expect(item.lastAccessedAt, isNotNull);
    final recent = await repo.watchRecentlyPlayed().first;
    expect(recent.map((r) => r.id), ['a']);
  });

  test('findItemByUrl matches with tracking params stripped (P9b-4)', () async {
    await db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: 'u1',
            title: 'Clip',
            sourceUrl: 'https://youtu.be/abc',
            site: 'youtube',
            filePath: '/m/u1',
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
          ),
        );
    final hit = await repo.findItemByUrl('https://youtu.be/abc?si=TRACK');
    expect(hit?.id, 'u1');
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

  test('renameCollection updates the name (P9g)', () async {
    final cId = await repo.createCollection('Old');
    await repo.renameCollection(cId, 'New');
    final names = [for (final c in await repo.watchCollections().first) c.name];
    expect(names, contains('New'));
    expect(names, isNot(contains('Old')));
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

    test('filters by tag name', () async {
      await seed('a', 'A', 'video');
      await seed('b', 'B', 'video');
      await repo.addTagToItem('a', 'funny');
      await repo.addTagToItem('b', 'serious');
      final rows = await repo
          .watchFiltered(const LibraryQuery(tag: 'funny'))
          .first;
      expect(rows.map((r) => r.id), ['a']);
    });

    test('search matches a word only in the transcript (P10h)', () async {
      await seed('a', 'Episode 1', 'video');
      await seed('b', 'Episode 2', 'video');
      await seedMeta('a', transcript: 'today we discuss photosynthesis');
      await seedMeta('b', transcript: 'a cooking lesson');
      final rows = await repo
          .watchFiltered(const LibraryQuery(search: 'photosynthesis'))
          .first;
      expect(rows.map((r) => r.id), ['a']);
    });

    test('relevance ranks stronger matches above newer ones (P10h)', () async {
      // 'a' is newer but matches 'forest' only once (in its description);
      // 'b' is older but matches it repeatedly in the title.
      await seed('a', 'Nature', 'video', day: 9);
      await seed('b', 'Forest forest forest forest', 'video', day: 1);
      await seedMeta('a', description: 'forest');
      final byRelevance = await repo
          .watchFiltered(
            const LibraryQuery(search: 'forest', sort: LibrarySort.relevance),
          )
          .first;
      expect(byRelevance.first.id, 'b');
      // The same query sorted by newest puts the newer item first instead.
      final byNewest = await repo
          .watchFiltered(
            const LibraryQuery(search: 'forest', sort: LibrarySort.newest),
          )
          .first;
      expect(byNewest.first.id, 'a');
    });

    test('hasTranscript filter excludes items without one (P10h)', () async {
      await seed('a', 'A', 'video');
      await seed('b', 'B', 'video');
      await seedMeta('a', transcript: 'some spoken words');
      await seedMeta('b'); // metadata row but no transcript
      final rows = await repo
          .watchFiltered(const LibraryQuery(hasTranscript: true))
          .first;
      expect(rows.map((r) => r.id), ['a']);
    });

    test('malformed FTS query is sanitized, not thrown (P10h)', () async {
      await seed('a', 'a-b test "quote', 'video');
      final rows = await repo
          .watchFiltered(const LibraryQuery(search: 'a-b "quote'))
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
