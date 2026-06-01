import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('opens at schema version 10 with all tables created', () async {
    expect(db.schemaVersion, 10);

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
        'notifications',
        'things',
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

  test('upgrades a v5 database to v6, adding the transcriptCues column', () async {
    // Seed a v5-schema DB (media_metadata has transcript but no transcriptCues)
    // at user_version=5 so opening AppDatabase (v6) runs the from<6 branch.
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
              tags TEXT,
              transcript TEXT
            )''');
          raw.execute(
            'INSERT INTO media_items (id, title, source_url, site, file_path, '
            'type, created_at, storage_state) VALUES '
            "('old1', 'Old clip', 'https://x/v', 'youtube', '/m/old1.mp4', "
            "'video', 0, 'private')",
          );
          raw.execute(
            'INSERT INTO media_metadata (item_id, transcript) VALUES '
            "('old1', 'flat transcript')",
          );
          raw.execute('PRAGMA user_version = 5');
        },
      ),
    );
    addTearDown(upgraded.close);

    // Old transcript survives; transcriptCues defaults to null and is writable.
    final meta = await upgraded.select(upgraded.mediaMetadata).getSingle();
    expect(meta.transcript, 'flat transcript');
    expect(meta.transcriptCues, isNull);

    await (upgraded.update(upgraded.mediaMetadata)
          ..where((t) => t.itemId.equals('old1')))
        .write(const MediaMetadataCompanion(transcriptCues: Value('[]')));
    final updated = await upgraded.select(upgraded.mediaMetadata).getSingle();
    expect(updated.transcriptCues, '[]');
  });

  test('upgrades a v6 database to v7, building & backfilling media_fts', () async {
    // Seed a v6-schema DB (no media_fts) at user_version=6 so opening
    // AppDatabase (v7) runs the from<7 branch and _createFtsObjects.
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
              tags TEXT,
              transcript TEXT,
              transcript_cues TEXT
            )''');
          raw.execute(
            'INSERT INTO media_items (id, title, source_url, site, file_path, '
            'type, created_at, storage_state) VALUES '
            "('old1', 'Cooking show', 'https://x/v', 'youtube', '/m/old1.mp4', "
            "'video', 0, 'private')",
          );
          raw.execute(
            'INSERT INTO media_metadata (item_id, description, transcript) '
            "VALUES ('old1', 'a tasty episode', 'we sauté the onions slowly')",
          );
          raw.execute('PRAGMA user_version = 6');
        },
      ),
    );
    addTearDown(upgraded.close);

    // The pre-existing row was backfilled into media_fts and is searchable by
    // a word that appears only in the transcript.
    final hits = await upgraded
        .customSelect(
          "SELECT item_id FROM media_fts WHERE media_fts MATCH 'onions'",
        )
        .get();
    expect(hits.map((r) => r.read<String>('item_id')), ['old1']);

    // The triggers keep the index live: editing the transcript updates results.
    await (upgraded.update(upgraded.mediaMetadata)
          ..where((t) => t.itemId.equals('old1')))
        .write(const MediaMetadataCompanion(transcript: Value('plain rice')));
    final after = await upgraded
        .customSelect(
          "SELECT item_id FROM media_fts WHERE media_fts MATCH 'onions'",
        )
        .get();
    expect(after, isEmpty);
  });

  test('upgrades a v7 database to v8, adding missing width/height columns', () async {
    // The bug P10i-c fixes: width/height shipped in the table definition but no
    // migration ever added them, so a DB upgraded to v7 lacks the columns. Seed
    // such a media_items table (no width/height) at user_version=7 and confirm
    // the v8 guard-migration repairs it without losing data.
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
              tags TEXT,
              transcript TEXT,
              transcript_cues TEXT
            )''');
          raw.execute(
            'INSERT INTO media_items (id, title, source_url, site, file_path, '
            'type, created_at, storage_state) VALUES '
            "('old1', 'Old clip', 'https://x/v', 'youtube', '/m/old1.mp4', "
            "'video', 0, 'private')",
          );
          raw.execute('PRAGMA user_version = 7');
        },
      ),
    );
    addTearDown(upgraded.close);

    // The old row survives; width/height now exist, default to null, and write.
    final item = await upgraded.select(upgraded.mediaItems).getSingle();
    expect(item.id, 'old1');
    expect(item.width, isNull);
    expect(item.height, isNull);

    await (upgraded.update(
      upgraded.mediaItems,
    )..where((t) => t.id.equals('old1'))).write(
      const MediaItemsCompanion(width: Value(1920), height: Value(1080)),
    );
    final updated = await upgraded.select(upgraded.mediaItems).getSingle();
    expect(updated.width, 1920);
    expect(updated.height, 1080);
  });

  test('upgrades a v8 database to v9, adding the notifications table', () async {
    // Seed a full v8-schema DB (no notifications table) at user_version=8 so
    // opening AppDatabase (v9) runs the from<9 onUpgrade branch.
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
              tags TEXT,
              transcript TEXT,
              transcript_cues TEXT
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
              created_at INTEGER NOT NULL,
              order_index INTEGER NOT NULL DEFAULT 0
            )''');
          raw.execute('''
            CREATE TABLE app_settings (
              id INTEGER NOT NULL PRIMARY KEY DEFAULT 0,
              data TEXT NOT NULL
            )''');
          raw.execute(
            'INSERT INTO media_items (id, title, source_url, site, file_path, '
            'type, created_at, storage_state) VALUES '
            "('old1', 'Old clip', 'https://x/v', 'youtube', '/m/old1.mp4', "
            "'video', 0, 'private')",
          );
          raw.execute('PRAGMA user_version = 8');
        },
      ),
    );
    addTearDown(upgraded.close);

    // The pre-existing row survives the upgrade.
    final item = await upgraded.select(upgraded.mediaItems).getSingle();
    expect(item.id, 'old1');

    // The new notifications table exists and round-trips an insert.
    await upgraded
        .into(upgraded.notifications)
        .insert(
          NotificationsCompanion.insert(
            id: 'ntf_test',
            category: 'system',
            severity: 'info',
            title: 'Hello',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        );
    final notifs = await upgraded.select(upgraded.notifications).get();
    expect(notifs, hasLength(1));
    expect(notifs.single.coalesceCount, 1);
    expect(notifs.single.readAt, isNull);

    // All five notification indices were created on upgrade.
    final indices = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' AND "
          "name LIKE 'idx_notifications_%'",
        )
        .get();
    expect(
      indices.map((r) => r.read<String>('name')).toSet(),
      containsAll(<String>[
        'idx_notifications_created_at',
        'idx_notifications_read_at',
        'idx_notifications_category',
        'idx_notifications_expires_at',
        'idx_notifications_dedupe_key',
      ]),
    );
  });

  test('upgrades a v9 database to v10, adding the empty things table', () async {
    // Seed a full v9-schema DB (with notifications, without things) at
    // user_version=9 so opening AppDatabase (v10) runs the from<10 branch.
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
              tags TEXT,
              transcript TEXT,
              transcript_cues TEXT
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
              created_at INTEGER NOT NULL,
              order_index INTEGER NOT NULL DEFAULT 0
            )''');
          raw.execute('''
            CREATE TABLE app_settings (
              id INTEGER NOT NULL PRIMARY KEY DEFAULT 0,
              data TEXT NOT NULL
            )''');
          raw.execute('''
            CREATE TABLE notifications (
              id TEXT NOT NULL PRIMARY KEY,
              category TEXT NOT NULL,
              severity TEXT NOT NULL,
              title TEXT NOT NULL,
              body TEXT,
              target_route TEXT,
              item_id TEXT,
              task_id TEXT,
              dedupe_key TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              read_at INTEGER,
              expires_at INTEGER,
              coalesce_count INTEGER NOT NULL DEFAULT 1
            )''');
          raw.execute(
            'INSERT INTO media_items (id, title, source_url, site, file_path, '
            'type, created_at, storage_state) VALUES '
            "('old1', 'Old clip', 'https://x/v', 'youtube', '/m/old1.mp4', "
            "'video', 0, 'private')",
          );
          raw.execute('PRAGMA user_version = 9');
        },
      ),
    );
    addTearDown(upgraded.close);

    // The pre-existing row survives the upgrade (no data loss).
    final item = await upgraded.select(upgraded.mediaItems).getSingle();
    expect(item.id, 'old1');

    // The new things table exists, starts empty, and round-trips an insert.
    expect(await upgraded.select(upgraded.things).get(), isEmpty);
    await upgraded
        .into(upgraded.things)
        .insert(
          ThingsCompanion.insert(
            id: 'thing1',
            type: 'VideoObject',
            jsonld: '{"@type":"VideoObject","name":"Demo"}',
            name: const Value('Demo'),
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        );
    final things = await upgraded.select(upgraded.things).get();
    expect(things, hasLength(1));
    expect(things.single.type, 'VideoObject');
    expect(things.single.name, 'Demo');
    expect(things.single.url, isNull);
  });

  test(
    'addColumnIfMissing is idempotent and adds only absent columns',
    () async {
      // Existing column → no-op (does not throw "duplicate column").
      await db.addColumnIfMissing('media_items', 'width');
      // Absent column → added.
      await db.addColumnIfMissing('media_items', 'zzz_probe');
      final cols = await db
          .customSelect('PRAGMA table_info(media_items)')
          .get();
      final names = cols.map((r) => r.read<String>('name')).toSet();
      expect(names, containsAll(<String>['width', 'height', 'zzz_probe']));
    },
  );
}
