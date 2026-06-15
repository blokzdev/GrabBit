import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/storage/media_storage.dart';
import 'package:grabbit/core/things/capture/capture_commit_service.dart';
import 'package:grabbit/core/utils/image_dimensions.dart';
import 'package:grabbit/core/utils/media_type.dart';
import 'package:grabbit/features/capture/data/file_import.dart';

/// A file the user picked to import: its source [path] and display [name].
typedef PickedFile = ({String path, String name});

/// The outcome of a file import (P16b-3), mapped to UI by the screen.
sealed class FileImportResult {
  const FileImportResult();
}

/// A media file (video/audio/image) was imported as a library [MediaItem]
/// (which auto-projects into a MediaObject Thing).
class FileImportedMedia extends FileImportResult {
  const FileImportedMedia(this.itemId, this.type);
  final String itemId;
  final String type;
}

/// A non-media file was asserted as a generic `DigitalDocument` Thing.
class FileImportedThing extends FileImportResult {
  const FileImportedThing(this.thingId);
  final String thingId;
}

/// The import failed.
class FileImportError extends FileImportResult {
  const FileImportError(this.message);
  final String message;
}

/// Imports a local file into the library (P16b-3). A media file becomes a
/// [MediaItem] (copied into app-private storage, then auto-projected to a
/// MediaObject Thing); any other file becomes a `DigitalDocument` Thing.
abstract interface class FileImportController {
  /// Opens the picker then imports the chosen file. Returns null if cancelled.
  Future<FileImportResult?> pickAndImport();

  /// Imports the file at [sourcePath] (display [fileName]) — the testable core.
  Future<FileImportResult> importFile({
    required String sourcePath,
    required String fileName,
  });
}

Future<PickedFile?> _defaultPick() async {
  final file = await openFile();
  if (file == null) return null;
  return (path: file.path, name: file.name);
}

class DefaultFileImportController implements FileImportController {
  DefaultFileImportController(
    this._db,
    this._commit,
    this._importDir, {
    Future<PickedFile?> Function()? pickFile,
    DateTime Function() now = DateTime.now,
    String Function()? newId,
  }) : _pickFile = pickFile ?? _defaultPick,
       _now = now,
       _newId = newId ?? (() => 'local_${now().microsecondsSinceEpoch}');

  final AppDatabase _db;
  final CaptureCommitService _commit;
  final Future<Directory> Function() _importDir;
  final Future<PickedFile?> Function() _pickFile;
  final DateTime Function() _now;
  final String Function() _newId;

  @override
  Future<FileImportResult?> pickAndImport() async {
    final picked = await _pickFile();
    if (picked == null) return null;
    return importFile(sourcePath: picked.path, fileName: picked.name);
  }

  @override
  Future<FileImportResult> importFile({
    required String sourcePath,
    required String fileName,
  }) async {
    try {
      final dir = await _importDir();
      final destDir = Directory(
        '${dir.path}/import_${_now().microsecondsSinceEpoch}',
      );
      await destDir.create(recursive: true);
      final destPath = '${destDir.path}/$fileName';
      await File(sourcePath).copy(destPath);

      final ext = _extOf(fileName);
      final mediaType = mediaTypeForExtOrNull(ext);
      final dest = File(destPath);
      final size = await dest.length();

      if (mediaType != null) {
        final dims = mediaType == 'image'
            ? await readImageDimensions(dest)
            : null;
        final itemId = _newId();
        await _db
            .into(_db.mediaItems)
            .insert(
              MediaItemsCompanion.insert(
                id: itemId,
                title: _stemOf(fileName),
                sourceUrl: 'file://$destPath',
                site: 'import',
                filePath: destPath,
                type: mediaType,
                createdAt: _now(),
                storageState: 'private',
                sizeBytes: Value(size),
                width: Value(dims?.$1),
                height: Value(dims?.$2),
              ),
            );
        return FileImportedMedia(itemId, mediaType);
      }

      final doc = buildDocumentThing(
        name: fileName,
        filePath: destPath,
        encodingFormat: encodingFormatForExt(ext),
        sizeBytes: size,
        now: _now,
      );
      final id = await _commit.commitThing(doc);
      return FileImportedThing(id);
    } on FileSystemException catch (e) {
      return FileImportError(e.message);
    } catch (e) {
      return FileImportError("Couldn't import this file. $e");
    }
  }

  String _extOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot >= 0 && dot < name.length - 1 ? name.substring(dot + 1) : '';
  }

  String _stemOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}

final fileImportControllerProvider = Provider<FileImportController>(
  (ref) => DefaultFileImportController(
    ref.watch(appDatabaseProvider),
    ref.watch(captureCommitServiceProvider),
    () => ref.watch(mediaStorageProvider).mediaDirectory(),
  ),
);
