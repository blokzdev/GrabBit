import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/utils/media_type.dart';

/// Persists a Media Studio output as a new library item, leaving the source
/// untouched. The new item inherits the source's folder + source URL.
class MediaToolsRepository {
  MediaToolsRepository(this._db);

  final AppDatabase _db;

  Future<void> saveEdited({
    required String id,
    required MediaItem source,
    required String title,
    required String outputPath,
    int? durationSec,
    int? sizeBytes,
    String? thumbPath,
  }) async {
    final ext = outputPath.split('.').last;
    await _db
        .into(_db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: id,
            title: title,
            sourceUrl: source.sourceUrl,
            site: source.site,
            filePath: outputPath,
            type: mediaTypeForExt(ext),
            createdAt: DateTime.now(),
            storageState: 'private',
            durationSec: Value(durationSec),
            sizeBytes: Value(sizeBytes),
            thumbPath: Value(thumbPath),
            folderId: Value(source.folderId),
          ),
        );
  }
}

final mediaToolsRepositoryProvider = Provider<MediaToolsRepository>(
  (ref) => MediaToolsRepository(ref.watch(appDatabaseProvider)),
);
