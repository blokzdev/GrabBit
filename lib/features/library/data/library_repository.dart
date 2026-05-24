import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/storage/media_export_service.dart';
import 'package:grabbit/core/utils/secure_delete.dart';

/// Library-level operations beyond plain queries (currently device export).
class LibraryRepository {
  LibraryRepository(this._db, this._export);

  final AppDatabase _db;
  final MediaExportService _export;

  /// Copies the item to the device and flips its storage_state to `exported`.
  Future<String> export(
    MediaItem item, {
    String? treeUri,
    String? subdir,
  }) async {
    final savedUri = await _export.export(
      filePath: item.filePath,
      type: item.type,
      treeUri: treeUri,
      subdir: subdir,
    );
    await (_db.update(_db.mediaItems)..where((t) => t.id.equals(item.id)))
        .write(const MediaItemsCompanion(storageState: Value('exported')));
    return savedUri;
  }

  /// Permanently removes an item: deletes its own media + thumbnail files
  /// (best-effort) then the DB row (metadata/tags/collections cascade via FK).
  /// Only the item's files are removed — the per-task folder may hold
  /// split-chapter siblings, so it's left in place. When [secure], file bytes
  /// are overwritten before unlinking (P9e; best-effort on flash storage).
  Future<void> deleteItem(MediaItem item, {bool secure = false}) async {
    for (final path in [item.filePath, item.thumbPath]) {
      if (path == null) continue;
      final file = File(path);
      if (file.existsSync()) {
        try {
          if (secure) {
            await secureDeleteFile(file);
          } else {
            await file.delete();
          }
        } on FileSystemException {
          // Best-effort: a missing/locked file shouldn't block DB removal.
        }
      }
    }
    _pruneEmptyParent(item.filePath);
    await (_db.delete(_db.mediaItems)..where((t) => t.id.equals(item.id))).go();
  }

  /// Removes the item's per-task folder once it's empty (split-chapter siblings
  /// keep it alive otherwise) so deletions don't leak directories (P9f).
  void _pruneEmptyParent(String? filePath) {
    if (filePath == null) return;
    try {
      final parent = File(filePath).parent;
      if (parent.existsSync() && parent.listSync().isEmpty) {
        parent.deleteSync();
      }
    } on FileSystemException {
      // Best-effort.
    }
  }
}

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(mediaExportServiceProvider),
  ),
);
