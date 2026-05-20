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

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Per-item extended metadata, 1:1 with [MediaItems].
class MediaMetadata extends Table {
  TextColumn get itemId =>
      text().references(MediaItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get uploader => text().nullable()();
  DateTimeColumn get uploadDate => dateTime().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get originalUrl => text().nullable()();

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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
