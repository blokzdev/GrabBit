import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';

/// CRUD + queries for the virtual Explorer folder tree (P5). Folders are a pure
/// DB hierarchy; deleting one orphans its children + media to the root (the
/// `folderId`/`parentId` FKs are `onDelete: setNull`).
class FolderRepository {
  FolderRepository(this._db);

  final AppDatabase _db;

  Stream<List<Folder>> watchSubfolders(int? parentId) =>
      (_db.select(_db.folders)
            ..where(
              (t) => parentId == null
                  ? t.parentId.isNull()
                  : t.parentId.equals(parentId),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Stream<List<Folder>> watchAllFolders() => (_db.select(
    _db.folders,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Stream<List<MediaItem>> watchItemsInFolder(int? folderId) =>
      (_db.select(_db.mediaItems)
            ..where(
              (t) => folderId == null
                  ? t.folderId.isNull()
                  : t.folderId.equals(folderId),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<int> createFolder(String name, {int? parentId}) => _db
      .into(_db.folders)
      .insert(
        FoldersCompanion.insert(
          name: name.trim(),
          parentId: Value(parentId),
          createdAt: DateTime.now(),
        ),
      );

  Future<void> renameFolder(int id, String name) =>
      (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(
        FoldersCompanion(name: Value(name.trim())),
      );

  /// Deletes a folder; its subfolders + media fall back to the root via setNull.
  Future<void> deleteFolder(int id) =>
      (_db.delete(_db.folders)..where((t) => t.id.equals(id))).go();

  Future<void> moveItems(List<String> itemIds, int? folderId) =>
      (_db.update(_db.mediaItems)..where((t) => t.id.isIn(itemIds))).write(
        MediaItemsCompanion(folderId: Value(folderId)),
      );

  Future<Folder?> folderById(int id) => (_db.select(
    _db.folders,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Root → … → current, for the Explorer breadcrumb.
  Future<List<Folder>> breadcrumb(int? folderId) async {
    final path = <Folder>[];
    var current = folderId;
    final seen = <int>{};
    while (current != null && seen.add(current)) {
      final folder = await folderById(current);
      if (folder == null) break;
      path.insert(0, folder);
      current = folder.parentId;
    }
    return path;
  }
}

final folderRepositoryProvider = Provider<FolderRepository>(
  (ref) => FolderRepository(ref.watch(appDatabaseProvider)),
);

// Hand-written (return Drift row types) per CLAUDE.md §8.
final subfoldersProvider = StreamProvider.family<List<Folder>, int?>(
  (ref, parentId) =>
      ref.watch(folderRepositoryProvider).watchSubfolders(parentId),
);

final folderItemsProvider = StreamProvider.family<List<MediaItem>, int?>(
  (ref, folderId) =>
      ref.watch(folderRepositoryProvider).watchItemsInFolder(folderId),
);

final allFoldersProvider = StreamProvider<List<Folder>>(
  (ref) => ref.watch(folderRepositoryProvider).watchAllFolders(),
);

final breadcrumbProvider = FutureProvider.family<List<Folder>, int?>(
  (ref, folderId) => ref.watch(folderRepositoryProvider).breadcrumb(folderId),
);

/// Current folder shown in the Explorer (null = root).
final explorerFolderProvider = NotifierProvider<ExplorerFolder, int?>(
  ExplorerFolder.new,
);

class ExplorerFolder extends Notifier<int?> {
  @override
  int? build() => null;
  void open(int? folderId) => state = folderId;
}
