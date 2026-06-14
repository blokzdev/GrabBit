import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/core/things/thing_repository.dart';

ThingDoc _doc({String type = 'VideoObject', String? name, String? url}) =>
    ThingDoc({'@type': type, 'name': ?name, 'url': ?url});

void main() {
  late AppDatabase db;
  late ThingRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ThingRepository(db);
  });
  tearDown(() => db.close());

  test(
    'upsertThing inserts and derives the promoted columns from the JSON-LD',
    () async {
      await repo.upsertThing(
        'm1',
        _doc(name: 'My Video', url: 'https://example.com/v'),
      );

      final row = await repo.thingById('m1');
      expect(row, isNotNull);
      expect(row!.type, 'VideoObject');
      expect(row.name, 'My Video');
      expect(row.url, 'https://example.com/v');
      // jsonld is the canonical payload, round-trippable.
      final doc = ThingDoc.fromJsonString(row.jsonld);
      expect(doc.name, 'My Video');
    },
  );

  test(
    'upsertThing leaves promoted columns null when the JSON-LD omits them',
    () async {
      await repo.upsertThing('m1', _doc()); // no name/url

      final row = await repo.thingById('m1');
      expect(row!.name, isNull);
      expect(row.url, isNull);
    },
  );

  test(
    're-upsert: JSON-LD wins, createdAt is preserved, updatedAt is bumped',
    () async {
      await repo.upsertThing(
        'm1',
        _doc(name: 'A', url: 'https://example.com/a'),
      );
      final first = await repo.thingById('m1');

      await repo.upsertThing(
        'm1',
        _doc(name: 'B', url: 'https://example.com/b'),
      );
      final second = await repo.thingById('m1');

      // Promoted cache + canonical payload both reflect the new doc.
      expect(second!.name, 'B');
      expect(second.url, 'https://example.com/b');
      expect(ThingDoc.fromJsonString(second.jsonld).name, 'B');
      // createdAt preserved byte-for-byte (read-then-write reuses it); updatedAt fresh.
      expect(second.createdAt, first!.createdAt);
      expect(second.updatedAt.isBefore(second.createdAt), isFalse);
    },
  );

  test('thingById returns null for an unknown id', () async {
    expect(await repo.thingById('nope'), isNull);
  });

  test(
    'watchThingsByType emits matching rows and excludes other types',
    () async {
      await repo.upsertThing('v1', _doc(type: 'VideoObject', name: 'vid'));
      await repo.upsertThing('r1', _doc(type: 'Recipe', name: 'recipe'));

      final videos = await repo.watchThingsByType('VideoObject').first;
      expect(videos.map((t) => t.id), ['v1']);
      expect(videos.single.name, 'vid');
    },
  );

  test('deleteThing removes the row', () async {
    await repo.upsertThing('m1', _doc(name: 'x'));
    await repo.deleteThing('m1');
    expect(await repo.thingById('m1'), isNull);
  });

  test('countThings / watchThingCount reflect the row count', () async {
    expect(await repo.countThings(), 0);
    await repo.upsertThing('a', _doc(name: 'a'));
    await repo.upsertThing('b', _doc(name: 'b'));
    expect(await repo.countThings(), 2);
    expect(await repo.watchThingCount().first, 2);
  });

  test(
    'refreshPromotedColumns re-derives drifted caches and is idempotent',
    () async {
      await repo.upsertThing(
        'm1',
        _doc(name: 'Real', url: 'https://example.com/v'),
      );
      // Corrupt the cache directly (simulating a stale promoted set).
      await (db.update(db.things)..where((t) => t.id.equals('m1'))).write(
        const ThingsCompanion(name: Value('WRONG'), url: Value(null)),
      );

      expect(await repo.refreshPromotedColumns(), 1);
      final row = await repo.thingById('m1');
      expect(row!.name, 'Real');
      expect(row.url, 'https://example.com/v');

      // Second run finds nothing to repair.
      expect(await repo.refreshPromotedColumns(), 0);
    },
  );

  test(
    'refreshPromotedColumns skips an unparseable row without throwing',
    () async {
      final now = DateTime.now();
      await db
          .into(db.things)
          .insert(
            ThingsCompanion.insert(
              id: 'bad',
              type: 'VideoObject',
              jsonld: 'not json',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await repo.upsertThing('good', _doc(name: 'Good'));
      await (db.update(db.things)..where((t) => t.id.equals('good'))).write(
        const ThingsCompanion(name: Value('STALE')),
      );

      expect(
        await repo.refreshPromotedColumns(),
        1,
      ); // only the good row repaired
      expect((await repo.thingById('good'))!.name, 'Good');
    },
  );
}
