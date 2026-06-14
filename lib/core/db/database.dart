import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Private media library entries (see docs/SPEC.md §3).
class MediaItems extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get sourceUrl => text()();
  TextColumn get site => text()();
  TextColumn get filePath => text()();
  TextColumn get type => text()(); // video | audio | image
  IntColumn get durationSec => integer().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  TextColumn get thumbPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get storageState => text()(); // private | exported
  TextColumn get notes => text().nullable()();
  // Virtual Explorer folder (P5); null = library root. Files stay physically flat.
  IntColumn get folderId => integer().nullable().references(
    Folders,
    #id,
    onDelete: KeyAction.setNull,
  )();
  // P9: starred item (P9b), content hash for duplicate detection (P9b, filled
  // lazily), and last-played timestamp (P9c) for "recent" browsing/sort (P9b).
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get contentHash => text().nullable()();
  DateTimeColumn get lastAccessedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Virtual, single-parent folder tree for the Explorer view (P5). Purely a DB
/// hierarchy — physical files are unaffected.
class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get parentId => integer().nullable().references(
    Folders,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get createdAt => dateTime()();
}

/// Per-item extended metadata, 1:1 with [MediaItems].
class MediaMetadata extends Table {
  TextColumn get itemId =>
      text().references(MediaItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get uploader => text().nullable()();
  DateTimeColumn get uploadDate => dateTime().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get originalUrl => text().nullable()();
  // Captured from the download's .info.json / expansion (P5) for faceted browsing.
  TextColumn get uploaderId => text().nullable()(); // channel handle / username
  TextColumn get channelId => text().nullable()();
  TextColumn get sourceId => text().nullable()(); // yt-dlp %(id)s
  TextColumn get playlistId => text().nullable()();
  TextColumn get playlistTitle => text().nullable()();
  TextColumn get tags => text().nullable()(); // comma-joined
  // P10f: plain-text transcript extracted from caption sidecars; feeds the
  // summary and (later) FTS/GraphRAG. Null until built.
  TextColumn get transcript => text().nullable()();
  // P10f-4: timestamped transcript lines (JSON) for the synced tap-to-seek
  // transcript view. Derived from the same captions as `transcript`.
  TextColumn get transcriptCues => text().nullable()();
  // P13a: cached on-device abstractive (LLM) summary of `transcript ?? description`,
  // generated on demand. Null until the user runs it; the extractive TextRank
  // summary is always the floor. `aiSummaryModelId` records which generation
  // model produced it (attribution + a "Regenerate" prompt when it changes).
  TextColumn get aiSummary => text().nullable()();
  TextColumn get aiSummaryModelId => text().nullable()();
  // P13b-1: on-device OCR text extracted from an image download. Null until the
  // user scans the image; feeds full-text search (media_fts) + the embed doc.
  TextColumn get ocrText => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {itemId};
}

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class MediaTags extends Table {
  TextColumn get itemId =>
      text().references(MediaItems, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();
  // P13c-2: provenance of this tag link — 'user' (manual/graph) or 'ai'
  // (auto-applied on download). Lets AI tags be marked + managed distinctly.
  TextColumn get source => text().withDefault(const Constant('user'))();

  @override
  Set<Column<Object>> get primaryKey => {itemId, tagId};
}

class Collections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
}

class MediaCollections extends Table {
  TextColumn get itemId =>
      text().references(MediaItems, #id, onDelete: KeyAction.cascade)();
  IntColumn get collectionId =>
      integer().references(Collections, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {itemId, collectionId};
}

/// Persistent download queue; survives process death (see ARCHITECTURE §6).
class DownloadTasks extends Table {
  TextColumn get id => text()();
  TextColumn get url => text()();
  TextColumn get requestJson => text()();
  TextColumn get status =>
      text()(); // queued | running | paused | done | error | canceled
  RealColumn get progress => real().withDefault(const Constant(0))();
  TextColumn get errorCode => text().nullable()();
  IntColumn get retries => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  // P9d: user-defined queue order (drag-to-reorder); ties broken by createdAt.
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// P11: the durable, on-device activity inbox (see ROADMAP §P11, SPEC §3).
/// Append-only log of everything the app does in the background. `itemId`
/// intentionally has NO foreign key: an entry must outlive the item it
/// references (a "download done" notice survives deleting that item), so a
/// cascade would wrongly erase history. Deep-link targets resolve defensively
/// at tap time.
class Notifications extends Table {
  TextColumn get id => text()(); // 'ntf_<micros>_<seq>'
  TextColumn get category =>
      text()(); // download | transcript | ai | graph | system | reminder
  TextColumn get severity => text()(); // info | success | warning | error
  TextColumn get title => text()();
  TextColumn get body => text().nullable()();
  TextColumn get targetRoute => text().nullable()(); // go_router deep-link
  TextColumn get itemId =>
      text().nullable()(); // MediaItems.id (no FK — see above)
  TextColumn get taskId => text().nullable()(); // DownloadTasks.id
  TextColumn get dedupeKey => text().nullable()(); // null = never coalesced
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()(); // bumped on coalesce
  DateTimeColumn get readAt => dateTime().nullable()(); // null = unread
  DateTimeColumn get expiresAt =>
      dateTime().nullable()(); // null = keep forever
  IntColumn get coalesceCount => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// **P12f forward seam — the P14 Things Engine corpus (empty until P14).** A generic,
/// typed graph of schema.org Things stored as **JSON-LD** ([jsonld] is the single
/// canonical payload). The other columns are a **denormalized cache** promoted out
/// of the JSON-LD for query/sort — never a second source of truth: on conflict the
/// JSON-LD wins and the columns are re-derived (ADR-0001). Created empty by the
/// v9→v10 migration; **nothing reads or writes it before P14** — the P14 Things Engine
/// projects `media_items` into MediaObject Things and fills richer types later.
///
/// [id] is a plain TEXT primary key kept **alignable to `media_items.id`**
/// (ADR-0003) but **intentionally without a foreign key**: a Thing may precede or
/// outlive a media row, and a full physical merge of the media tables is a
/// deferred, open question. **Drift stays canonical**; Cozo stays the derived index.
class Things extends Table {
  TextColumn get id => text()(); // alignable to MediaItems.id, no FK (ADR-0003)
  TextColumn get type =>
      text()(); // schema.org @type, e.g. Recipe | VideoObject
  TextColumn get jsonld => text()(); // canonical JSON-LD document (ADR-0001)
  TextColumn get name =>
      text().nullable()(); // promoted cache of jsonld['name']
  TextColumn get url => text().nullable()(); // promoted cache of jsonld['url']
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Single-row settings blob (JSON), keyed on a fixed id (see SPEC §4).
class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  TextColumn get data => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// P13d-2a: a persisted "Ask your library" GraphRAG conversation. Each chat is a
/// multi-turn thread of [ChatMessages]; every turn re-retrieves fresh sources
/// and feeds back a bounded slice of this history. `title` is derived from the
/// first question (renamable in d-2b); `archivedAt` (null = active) backs the
/// d-2b archive action. Forward-compatible so d-2b needs no further migration.
class Chats extends Table {
  TextColumn get id => text()(); // 'chat_<micros>'
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()(); // bumped each turn → list sort
  DateTimeColumn get archivedAt => dateTime().nullable()(); // null = active

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// P13d-2a: one message in a [Chats] thread. `id` autoincrements for natural
/// per-chat ordering; deleting a chat cascades its messages. `citationsJson`
/// (assistant turns only) stores the cited sources as compact JSON so the inline
/// `[n]` citations stay tappable after the chat is reloaded.
class ChatMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get chatId =>
      text().references(Chats, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()(); // user | assistant
  TextColumn get content => text()();
  TextColumn get citationsJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(
  tables: [
    MediaItems,
    Folders,
    MediaMetadata,
    Tags,
    MediaTags,
    Collections,
    MediaCollections,
    DownloadTasks,
    AppSettings,
    Notifications,
    Things,
    Chats,
    ChatMessages,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'grabbit'));

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndices();
      await _createFtsObjects();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(folders);
        await m.addColumn(mediaItems, mediaItems.folderId);
        await m.addColumn(mediaMetadata, mediaMetadata.uploaderId);
        await m.addColumn(mediaMetadata, mediaMetadata.channelId);
        await m.addColumn(mediaMetadata, mediaMetadata.sourceId);
        await m.addColumn(mediaMetadata, mediaMetadata.playlistId);
        await m.addColumn(mediaMetadata, mediaMetadata.playlistTitle);
        await m.addColumn(mediaMetadata, mediaMetadata.tags);
      }
      if (from < 3) {
        await m.addColumn(mediaItems, mediaItems.isFavorite);
        await m.addColumn(mediaItems, mediaItems.contentHash);
        await m.addColumn(mediaItems, mediaItems.lastAccessedAt);
        await m.addColumn(downloadTasks, downloadTasks.orderIndex);
      }
      if (from < 5) {
        await m.addColumn(mediaMetadata, mediaMetadata.transcript);
      }
      if (from < 6) {
        await m.addColumn(mediaMetadata, mediaMetadata.transcriptCues);
      }
      if (from < 8) {
        // width/height shipped in the table definition without a migration, so
        // DBs upgraded across that version lack the columns while fresh installs
        // have them — guard-add to repair the former without breaking the latter.
        await addColumnIfMissing('media_items', 'width');
        await addColumnIfMissing('media_items', 'height');
      }
      if (from < 9) {
        await m.createTable(notifications);
      }
      if (from < 10) {
        // P12f forward seam: the empty `things` table (P14 Things Engine). No
        // data migration — created empty; nothing reads/writes it before P14.
        await m.createTable(things);
      }
      if (from < 11) {
        // P13a: cached on-device LLM summary + the model that produced it.
        await m.addColumn(mediaMetadata, mediaMetadata.aiSummary);
        await m.addColumn(mediaMetadata, mediaMetadata.aiSummaryModelId);
      }
      if (from < 12) {
        // P13b-1: OCR text column + add it to the FTS index. FTS5 can't
        // ALTER ADD COLUMN, so drop the table + triggers and let
        // `_createFtsObjects` rebuild them (now with `ocr`) and backfill.
        await m.addColumn(mediaMetadata, mediaMetadata.ocrText);
        for (final t in const [
          'media_fts_ai_items',
          'media_fts_au_items',
          'media_fts_ad_items',
          'media_fts_ai_meta',
          'media_fts_au_meta',
          'media_fts_ad_meta',
        ]) {
          await customStatement('DROP TRIGGER IF EXISTS $t');
        }
        await customStatement('DROP TABLE IF EXISTS media_fts');
      }
      if (from < 13) {
        // P13c-2: tag provenance ('user' default; 'ai' for auto-applied tags).
        // Defensive table guard (mirrors the v8 guard-add spirit): a no-op if
        // media_tags somehow isn't present yet.
        final hasMediaTags = (await customSelect(
          "SELECT 1 FROM sqlite_master WHERE type='table' "
          "AND name='media_tags'",
        ).get()).isNotEmpty;
        if (hasMediaTags) await m.addColumn(mediaTags, mediaTags.source);
      }
      if (from < 14) {
        // P13d-2a: persisted "Ask your library" chats. New tables only — no
        // data migration (mirrors the v8→v9 notifications / v9→v10 things steps).
        await m.createTable(chats);
        await m.createTable(chatMessages);
      }
      await _createIndices();
      await _createFtsObjects();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Adds a nullable INTEGER [column] to [table] only when it isn't already
  /// present. Idempotent: a no-op when `createAll` already produced the column
  /// (fresh installs), a real `ALTER TABLE` when an older DB upgraded without it.
  Future<void> addColumnIfMissing(String table, String column) async {
    final info = await customSelect('PRAGMA table_info($table)').get();
    final exists = info.any((row) => row.read<String>('name') == column);
    if (!exists) {
      await customStatement('ALTER TABLE $table ADD COLUMN $column INTEGER');
    }
  }

  /// Facet indices for library filtering/browsing. Idempotent so it can run on
  /// both fresh creates and upgrades.
  Future<void> _createIndices() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_items_site ON media_items (site)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_items_folder ON media_items (folder_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_metadata_uploader ON media_metadata (uploader)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_metadata_uploader_id ON media_metadata (uploader_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_metadata_playlist_id ON media_metadata (playlist_id)',
    );
    // P9: favorites filter, dedupe lookups, and the default (date) library sort.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_items_favorite ON media_items (is_favorite)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_items_content_hash ON media_items (content_hash)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_items_created_at ON media_items (created_at)',
    );
    // P9b-4: fast source-id lookups for preventive (pre-download) dedupe.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_metadata_source_id ON media_metadata (source_id)',
    );
    // P11: activity inbox — feed order, unread badge, category filter, lazy
    // retention sweep, and dedupe-key coalesce lookups.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications (created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notifications_read_at ON notifications (read_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notifications_category ON notifications (category)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notifications_expires_at ON notifications (expires_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_notifications_dedupe_key ON notifications (dedupe_key)',
    );
  }

  /// P10h: the full-text search index over title + description + transcript.
  ///
  /// `media_fts` is a standard (not external-content) FTS5 table keyed by
  /// `item_id`, because the searchable text spans two tables — `title` lives on
  /// `media_items`, `description`/`transcript` on `media_metadata`. Triggers on
  /// both tables keep it in sync (delete-then-reinsert the joined row), so edits
  /// to a title or a transcript immediately update search results. Idempotent
  /// (`IF NOT EXISTS` + a backfill `NOT IN` guard) so it runs safely on both
  /// fresh creates and v6→v7 upgrades. Not declared as a Drift table.
  Future<void> _createFtsObjects() async {
    await customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS media_fts USING fts5('
      'item_id UNINDEXED, title, description, transcript, ocr, '
      "tokenize = 'unicode61 remove_diacritics 2')",
    );
    // media_items → fts (title is here; description/transcript/ocr joined in).
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS media_fts_ai_items '
      'AFTER INSERT ON media_items BEGIN '
      'DELETE FROM media_fts WHERE item_id = new.id; '
      'INSERT INTO media_fts(item_id, title, description, transcript, ocr) '
      'SELECT new.id, new.title, '
      '(SELECT description FROM media_metadata WHERE item_id = new.id), '
      '(SELECT transcript FROM media_metadata WHERE item_id = new.id), '
      '(SELECT ocr_text FROM media_metadata WHERE item_id = new.id); END',
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS media_fts_au_items '
      'AFTER UPDATE OF title ON media_items BEGIN '
      'DELETE FROM media_fts WHERE item_id = new.id; '
      'INSERT INTO media_fts(item_id, title, description, transcript, ocr) '
      'SELECT new.id, new.title, '
      '(SELECT description FROM media_metadata WHERE item_id = new.id), '
      '(SELECT transcript FROM media_metadata WHERE item_id = new.id), '
      '(SELECT ocr_text FROM media_metadata WHERE item_id = new.id); END',
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS media_fts_ad_items '
      'AFTER DELETE ON media_items BEGIN '
      'DELETE FROM media_fts WHERE item_id = old.id; END',
    );
    // media_metadata → fts (description/transcript/ocr here; title joined in).
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS media_fts_ai_meta '
      'AFTER INSERT ON media_metadata BEGIN '
      'DELETE FROM media_fts WHERE item_id = new.item_id; '
      'INSERT INTO media_fts(item_id, title, description, transcript, ocr) '
      'SELECT new.item_id, '
      '(SELECT title FROM media_items WHERE id = new.item_id), '
      'new.description, new.transcript, new.ocr_text; END',
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS media_fts_au_meta '
      'AFTER UPDATE OF description, transcript, ocr_text ON media_metadata BEGIN '
      'DELETE FROM media_fts WHERE item_id = new.item_id; '
      'INSERT INTO media_fts(item_id, title, description, transcript, ocr) '
      'SELECT new.item_id, '
      '(SELECT title FROM media_items WHERE id = new.item_id), '
      'new.description, new.transcript, new.ocr_text; END',
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS media_fts_ad_meta '
      'AFTER DELETE ON media_metadata BEGIN '
      'DELETE FROM media_fts WHERE item_id = old.item_id; '
      'INSERT INTO media_fts(item_id, title, description, transcript, ocr) '
      'SELECT old.item_id, title, NULL, NULL, NULL FROM media_items '
      'WHERE id = old.item_id; END',
    );
    // One-time backfill of pre-existing rows (no-op on a fresh, empty DB).
    await customStatement(
      'INSERT INTO media_fts(item_id, title, description, transcript, ocr) '
      'SELECT mi.id, mi.title, mm.description, mm.transcript, mm.ocr_text '
      'FROM media_items mi '
      'LEFT JOIN media_metadata mm ON mm.item_id = mi.id '
      'WHERE mi.id NOT IN (SELECT item_id FROM media_fts)',
    );
  }
}
