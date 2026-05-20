import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('opens at schema version 1 with all tables created', () async {
    expect(db.schemaVersion, 1);

    // Forces onCreate (createAll) + beforeOpen to run.
    final tableNames = db.allTables.map((t) => t.actualTableName).toSet();
    expect(
      tableNames,
      containsAll(<String>[
        'media_items',
        'media_metadata',
        'tags',
        'media_tags',
        'collections',
        'media_collections',
        'download_tasks',
        'app_settings',
      ]),
    );

    // A round-trip insert proves the schema is materialized.
    await db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: 'abc',
            title: 'Test',
            sourceUrl: 'https://example.com/v',
            site: 'example',
            filePath: '/tmp/abc.mp4',
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
          ),
        );
    final rows = await db.select(db.mediaItems).get();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'Test');
  });

  test('foreign key cascade deletes dependent metadata', () async {
    await db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: 'item1',
            title: 'T',
            sourceUrl: 'u',
            site: 's',
            filePath: 'p',
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
          ),
        );
    await db
        .into(db.mediaMetadata)
        .insert(const MediaMetadataCompanion(itemId: Value('item1')));

    await (db.delete(db.mediaItems)..where((t) => t.id.equals('item1'))).go();

    final meta = await db.select(db.mediaMetadata).get();
    expect(meta, isEmpty);
  });
}
