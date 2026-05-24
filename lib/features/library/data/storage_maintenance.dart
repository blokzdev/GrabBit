import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/storage/media_storage.dart';

/// Reclaims storage leaked by deletions: per-task folders and split-chapter
/// siblings are left on disk when a library item/task is removed (P9f). Reused
/// by the Storage screen's "Clean up leftover files" action.
class StorageMaintenance {
  StorageMaintenance(this._db, this._storage);

  final AppDatabase _db;
  final MediaStorage _storage;

  /// Deletes files under the media root that no library item references, plus
  /// any now-empty directories. Returns how many files were removed and the
  /// total bytes reclaimed.
  Future<({int files, int bytes})> cleanupOrphans() async {
    final dir = await _storage.mediaDirectory();
    if (!dir.existsSync()) return (files: 0, bytes: 0);

    final referenced = await _referencedPaths();
    var files = 0;
    var bytes = 0;
    for (final entity in dir.listSync(recursive: true).whereType<File>()) {
      if (referenced.contains(entity.path)) continue;
      try {
        bytes += entity.lengthSync();
        entity.deleteSync();
        files++;
      } on FileSystemException {
        // Best-effort: skip a locked/vanished file.
      }
    }
    _pruneEmptyDirs(dir);
    return (files: files, bytes: bytes);
  }

  Future<Set<String>> _referencedPaths() async {
    final query = _db.selectOnly(_db.mediaItems)
      ..addColumns([_db.mediaItems.filePath, _db.mediaItems.thumbPath]);
    final rows = await query.get();
    return {
      for (final row in rows) ...[
        row.read(_db.mediaItems.filePath),
        row.read(_db.mediaItems.thumbPath),
      ],
    }.whereType<String>().toSet();
  }

  /// Removes empty directories bottom-up, leaving the media root itself.
  void _pruneEmptyDirs(Directory root) {
    final dirs = root.listSync(recursive: true).whereType<Directory>().toList()
      ..sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final d in dirs) {
      try {
        if (d.listSync().isEmpty) d.deleteSync();
      } on FileSystemException {
        // Ignore: not empty or vanished.
      }
    }
  }
}

final storageMaintenanceProvider = Provider<StorageMaintenance>(
  (ref) => StorageMaintenance(
    ref.watch(appDatabaseProvider),
    ref.watch(mediaStorageProvider),
  ),
);
