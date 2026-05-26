import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('opens at schema version 5 with all tables created', () async {
    expect(db.schemaVersion, 5);

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

  test('creates the source_id index (P9b-4)', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' AND "
          "name='idx_media_metadata_source_id'",
        )
        .get();
    expect(rows, hasLength(1));
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
          // A real v1 DB also has download_tasks; the later from<3 branch
          // alters it, so it must exist for the upgrade to apply.
          raw.execute('''
            CREATE TABLE download_tasks (
              id TEXT NOT NULL PRIMARY KEY,
              url TEXT NOT NULL,
              request_json TEXT NOT NULL,
              status TEXT NOT NULL,
              progress REAL NOT NULL DEFAULT 0,
              error_code TEXT,
              retries INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
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

  test('upgrades a v2 database to v3 without losing data', () async {
    // Seed a v2-schema DB (media_items with folder_id but no P9 columns;
    // download_tasks without order_index) at user_version=2 so opening
    // AppDatabase (v3) runs the from<3 onUpgrade branch.
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
              notes TEXT,
              folder_id INTEGER
            )''');
          // A real v2 DB has media_metadata; _createIndices indexes it.
          raw.execute('''
            CREATE TABLE media_metadata (
              item_id TEXT NOT NULL PRIMARY KEY REFERENCES media_items (id),
              uploader TEXT,
              upload_date INTEGER,
              description TEXT,
              original_url TEXT,
              uploader_id TEXT,
              channel_id TEXT,
              source_id TEXT,
              playlist_id TEXT,
              playlist_title TEXT,
              tags TEXT
            )''');
          raw.execute('''
            CREATE TABLE download_tasks (
              id TEXT NOT NULL PRIMARY KEY,
              url TEXT NOT NULL,
              request_json TEXT NOT NULL,
              status TEXT NOT NULL,
              progress REAL NOT NULL DEFAULT 0,
              error_code TEXT,
              retries INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            )''');
          raw.execute(
            'INSERT INTO media_items (id, title, source_url, site, file_path, '
            'type, created_at, storage_state) VALUES '
            "('old1', 'Old clip', 'https://x/v', 'youtube', '/m/old1.mp4', "
            "'video', 0, 'private')",
          );
          raw.execute(
            'INSERT INTO download_tasks (id, url, request_json, status, '
            "created_at) VALUES ('t1', 'https://x/v', '{}', 'done', 0)",
          );
          raw.execute('PRAGMA user_version = 2');
        },
      ),
    );
    addTearDown(upgraded.close);

    // Old rows survive with the new columns' defaults applied.
    final item = await upgraded.select(upgraded.mediaItems).getSingle();
    expect(item.id, 'old1');
    expect(item.isFavorite, isFalse);
    expect(item.contentHash, isNull);
    expect(item.lastAccessedAt, isNull);

    final task = await upgraded.select(upgraded.downloadTasks).getSingle();
    expect(task.orderIndex, 0);

    // New columns are writable.
    await (upgraded.update(
      upgraded.mediaItems,
    )..where((t) => t.id.equals('old1'))).write(
      MediaItemsCompanion(
        isFavorite: const Value(true),
        contentHash: const Value('deadbeef'),
        lastAccessedAt: Value(DateTime.utc(2026, 5, 23)),
      ),
    );
    final updated = await upgraded.select(upgraded.mediaItems).getSingle();
    expect(updated.isFavorite, isTrue);
    expect(updated.contentHash, 'deadbeef');
    expect(
      updated.lastAccessedAt!.isAtSameMomentAs(DateTime.utc(2026, 5, 23)),
      isTrue,
    );
  });

  test('upgrades a v4 database to v5, adding the transcript column', () async {
    // Seed a v4-schema DB (media_metadata without the P10f transcript column)
    // at user_version=4 so opening AppDatabase (v5) runs the from<5 branch.
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
              notes TEXT,
              folder_id INTEGER,
              is_favorite INTEGER NOT NULL DEFAULT 0,
              content_hash TEXT,
              last_accessed_at INTEGER
            )''');
          raw.execute('''
            CREATE TABLE media_metadata (
              item_id TEXT NOT NULL PRIMARY KEY REFERENCES media_items (id),
              uploader TEXT,
              upload_date INTEGER,
              description TEXT,
              original_url TEXT,
              uploader_id TEXT,
              channel_id TEXT,
              source_id TEXT,
              playlist_id TEXT,
              playlist_title TEXT,
              tags TEXT
            )''');
          raw.execute(
            'INSERT INTO media_items (id, title, source_url, site, file_path, '
            'type, created_at, storage_state) VALUES '
            "('old1', 'Old clip', 'https://x/v', 'youtube', '/m/old1.mp4', "
            "'video', 0, 'private')",
          );
          raw.execute(
            'INSERT INTO media_metadata (item_id, description) VALUES '
            "('old1', 'a description')",
          );
          raw.execute('PRAGMA user_version = 4');
        },
      ),
    );
    addTearDown(upgraded.close);

    // Old metadata survives; transcript defaults to null and is writable.
    final meta = await upgraded.select(upgraded.mediaMetadata).getSingle();
    expect(meta.description, 'a description');
    expect(meta.transcript, isNull);

    await (upgraded.update(upgraded.mediaMetadata)
          ..where((t) => t.itemId.equals('old1')))
        .write(const MediaMetadataCompanion(transcript: Value('hello world')));
    final updated = await upgraded.select(upgraded.mediaMetadata).getSingle();
    expect(updated.transcript, 'hello world');
  });
}
