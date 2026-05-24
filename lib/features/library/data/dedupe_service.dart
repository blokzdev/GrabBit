import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';

/// Bytes hashed from each end of a file. A duplicate of the same download
/// matches on (size + head + tail) without reading the whole (large) video.
const _hashWindow = 1 << 20; // 1 MiB

/// Content signature for each readable path: `sha256(size + first 1 MiB +
/// last 1 MiB)` (whole file when smaller). Top-level + synchronous so it can run
/// inside `compute` (its own isolate). Missing/unreadable files are skipped.
Map<String, String> hashFilesSync(List<String> paths) {
  final out = <String, String>{};
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    RandomAccessFile? raf;
    try {
      final len = file.lengthSync();
      raf = file.openSync();
      final head = raf.readSync(math.min(_hashWindow, len));
      var tail = const <int>[];
      if (len > _hashWindow) {
        raf.setPositionSync(len - _hashWindow);
        tail = raf.readSync(_hashWindow);
      }
      final digest = sha256.convert([...'$len:'.codeUnits, ...head, ...tail]);
      out[path] = digest.toString();
    } on FileSystemException {
      // Skip unreadable files.
    } finally {
      raf?.closeSync();
    }
  }
  return out;
}

/// Populates `media_items.contentHash` for items that don't have one yet, so
/// duplicate detection (P9b-3) can group them. Hashing runs off the UI isolate.
class DedupeService {
  DedupeService(this._db);

  final AppDatabase _db;

  /// Hashes all not-yet-hashed items and writes the signatures back. Returns the
  /// number of items hashed.
  Future<int> scan() async {
    final pending = await (_db.select(
      _db.mediaItems,
    )..where((t) => t.contentHash.isNull())).get();
    if (pending.isEmpty) return 0;

    final byPath = {for (final item in pending) item.filePath: item.id};
    final hashes = await compute(hashFilesSync, byPath.keys.toList());

    await _db.batch((batch) {
      hashes.forEach((path, hash) {
        final id = byPath[path];
        if (id == null) return;
        batch.update(
          _db.mediaItems,
          MediaItemsCompanion(contentHash: Value(hash)),
          where: (t) => t.id.equals(id),
        );
      });
    });
    return hashes.length;
  }
}

final dedupeServiceProvider = Provider<DedupeService>(
  (ref) => DedupeService(ref.watch(appDatabaseProvider)),
);
