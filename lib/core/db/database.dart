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

/// Single-row settings blob (JSON), keyed on a fixed id (see SPEC §4).
class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  TextColumn get data => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'grabbit'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndices();
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
      await _createIndices();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

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
  }
}
