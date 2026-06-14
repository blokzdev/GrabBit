import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/thing_projection_service.dart';
import 'package:grabbit/core/things/thing_repository.dart';

void main() {
  late AppDatabase db;
  late ThingRepository repo;
  late ThingProjectionService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ThingRepository(db);
    service = ThingProjectionService(repo, db);
  });
  tearDown(() => db.close());

  Future<void> addItem(
    String id, {
    String title = 'T',
    String type = 'video',
    String? uploader,
  }) async {
    await db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: id,
            title: title,
            sourceUrl: 'https://example.com/$id',
            site: 'example',
            filePath: '/files/$id',
            type: type,
            createdAt: DateTime.utc(2026),
            storageState: 'private',
          ),
        );
    if (uploader != null) {
      await db
          .into(db.mediaMetadata)
          .insert(
            MediaMetadataCompanion.insert(
              itemId: id,
              uploader: Value(uploader),
            ),
          );
    }
  }

  test(
    'backfill projects every media item into a typed MediaObject Thing',
    () async {
      await addItem('a', type: 'video', uploader: 'chan');
      await addItem('b', type: 'image');

      final stats = await service.backfillMediaObjects();
      expect(stats.upserted, 2);
      expect(await repo.countThings(), 2);

      final a = await repo.thingById('a');
      expect(a!.type, 'VideoObject');
      expect(a.name, 'T');
      expect(a.url, 'https://example.com/a');
      expect((await repo.thingById('b'))!.type, 'ImageObject');
    },
  );

  test(
    'backfill is idempotent — a second run writes nothing, createdAt preserved',
    () async {
      await addItem('a');
      await service.backfillMediaObjects();
      final first = await repo.thingById('a');

      final stats = await service.backfillMediaObjects();
      expect(stats.upserted, 0);
      expect(stats.pruned, 0);
      expect(await repo.countThings(), 1);
      expect((await repo.thingById('a'))!.createdAt, first!.createdAt);
      expect((await repo.thingById('a'))!.updatedAt, first.updatedAt);
    },
  );

  test(
    'a changed item re-projects; untouched items keep their updatedAt',
    () async {
      await addItem('a', title: 'Old');
      await addItem('b', title: 'Keep');
      await service.backfillMediaObjects();
      final bBefore = await repo.thingById('b');

      await (db.update(db.mediaItems)..where((t) => t.id.equals('a'))).write(
        const MediaItemsCompanion(title: Value('New')),
      );
      final stats = await service.backfillMediaObjects();

      expect(stats.upserted, 1); // only 'a'
      expect((await repo.thingById('a'))!.name, 'New');
      expect((await repo.thingById('b'))!.updatedAt, bBefore!.updatedAt);
    },
  );

  test('backfill prunes a MediaObject Thing whose media row is gone', () async {
    await addItem('a');
    await addItem('b');
    await service.backfillMediaObjects();

    await (db.delete(db.mediaItems)..where((t) => t.id.equals('b'))).go();
    final stats = await service.backfillMediaObjects();

    expect(stats.pruned, 1);
    expect(await repo.thingById('b'), isNull);
    expect(await repo.countThings(), 1);
  });

  test('prune leaves non-MediaObject Things untouched', () async {
    await addItem('a');
    // A future, non-projected Thing type (e.g. P15 extraction).
    await db
        .into(db.things)
        .insert(
          ThingsCompanion.insert(
            id: 'recipe-1',
            type: 'Recipe',
            jsonld: '{"@type":"Recipe","name":"Soup"}',
            name: const Value('Soup'),
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        );

    final stats = await service.backfillMediaObjects();
    expect(stats.pruned, 0);
    expect(await repo.thingById('recipe-1'), isNotNull);
    expect(await repo.countThings(), 2); // the MediaObject + the Recipe
  });
}
