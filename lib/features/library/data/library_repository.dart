import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/storage/media_export_service.dart';

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
}

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(mediaExportServiceProvider),
  ),
);
