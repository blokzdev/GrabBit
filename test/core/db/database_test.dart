import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('opens at schema version 2 with all tables created', () async {
    expect(db.schemaVersion, 2);

    // Forces onCreate (createAll) + beforeOpen to run.
    final tableNames = db.allTables.map((t) => t.actualTableName).toSet();
    expect(
      tableNames,
      containsAll(<String>[
        'media_items',
        'folders',
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

  test('upgrades a v1 database to v2 without losing data', () async {
    // Seed a v1-schema DB (no folders table / folderId / new metadata columns)
    // at user_version=1 so opening AppDatabase (v2) runs onUpgrade.
    final upgraded = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
            CREATE TABLE media_items (
              id TEXT NOT NULL PRIMARY KEY,
              title TEXT NOT NULL,
              source_url TEXT NOT NULL,
              site TEXT NOT NULL,
              file_path TEXT NOT NULL,
              type TEXT NOT NULL,
              duration_sec INTEGER,
              size_bytes INTEGER,
              width INTEGER,
              height INTEGER,
              thumb_path TEXT,
              created_at INTEGER NOT NULL,
              storage_state TEXT NOT NULL,
              notes TEXT
            )''');
          raw.execute('''
            CREATE TABLE media_metadata (
              item_id TEXT NOT NULL PRIMARY KEY REFERENCES media_items (id),
              uploader TEXT,
              upload_date INTEGER,
              description TEXT,
              original_url TEXT
            )''');
          raw.execute(
            'INSERT INTO media_items (id, title, source_url, site, file_path, '
            'type, created_at, storage_state) VALUES '
            "('old1', 'Old clip', 'https://x/v', 'youtube', '/m/old1.mp4', "
            "'video', 0, 'private')",
          );
          raw.execute('PRAGMA user_version = 1');
        },
      ),
    );
    addTearDown(upgraded.close);

    // The old row survives and lands at the root (folderId null).
    final item = await upgraded.select(upgraded.mediaItems).getSingle();
    expect(item.id, 'old1');
    expect(item.folderId, isNull);

    // New schema is present: folders table + new metadata columns are usable.
    expect(await upgraded.select(upgraded.folders).get(), isEmpty);
    await upgraded
        .into(upgraded.folders)
        .insert(
          FoldersCompanion.insert(name: 'Music', createdAt: DateTime.utc(2026)),
        );
    await upgraded
        .into(upgraded.mediaMetadata)
        .insert(
          MediaMetadataCompanion.insert(
            itemId: 'old1',
            uploaderId: const Value('rick'),
            playlistId: const Value('PL1'),
          ),
        );
    final meta = await upgraded.select(upgraded.mediaMetadata).getSingle();
    expect(meta.uploaderId, 'rick');
    expect(meta.playlistId, 'PL1');
  });
}
