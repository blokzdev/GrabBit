import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/thing_hydration.dart';

void main() {
  late AppDatabase db;
  late NodeHydration hydrate;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    hydrate = NodeHydration(db);
  });
  tearDown(() => db.close());

  Future<void> addMedia(String id, String title) => db
      .into(db.mediaItems)
      .insert(
        MediaItemsCompanion.insert(
          id: id,
          title: title,
          sourceUrl: 'https://e/$id',
          site: 'example',
          filePath: '/m/$id',
          type: 'video',
          createdAt: DateTime.utc(2026),
          storageState: 'private',
        ),
      );

  Future<void> addThing(String id, String type, String name) => db
      .into(db.things)
      .insert(
        ThingsCompanion.insert(
          id: id,
          type: type,
          jsonld: '{"@type":"$type","name":"$name"}',
          name: Value(name),
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );

  test(
    'Thing-backed node: title from Thing.name, type set, media attached',
    () async {
      await addMedia('a', 'Media Title');
      await addThing('a', 'VideoObject', 'Thing Name');

      final nodes = await hydrate.hydrateNodes(['a']);
      expect(nodes.single.title, 'Thing Name'); // Thing wins
      expect(nodes.single.type, 'VideoObject');
      expect(nodes.single.media!.id, 'a');
    },
  );

  test('media-only node falls back to the media title, type null', () async {
    await addMedia('a', 'Just Media');
    final nodes = await hydrate.hydrateNodes(['a']);
    expect(nodes.single.title, 'Just Media');
    expect(nodes.single.type, isNull);
    expect(nodes.single.media!.id, 'a');
  });

  test('preserves input order and skips unknown ids', () async {
    await addMedia('a', 'A');
    await addMedia('b', 'B');
    final nodes = await hydrate.hydrateNodes(['b', 'missing', 'a']);
    expect(nodes.map((n) => n.id), ['b', 'a']); // order kept, 'missing' dropped
  });

  test('a non-media Thing (no media row) still resolves', () async {
    await addThing('r1', 'Recipe', 'Soup'); // no media row
    final nodes = await hydrate.hydrateNodes(['r1']);
    expect(nodes.single.title, 'Soup');
    expect(nodes.single.type, 'Recipe');
    expect(nodes.single.media, isNull);
  });

  test('empty input → empty output', () async {
    expect(await hydrate.hydrateNodes(const []), isEmpty);
  });
}
