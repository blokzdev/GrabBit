import 'dart:io';

import 'package:drift/drift.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/engine/info_json_parser.dart';
import 'package:grabbit/core/utils/image_dimensions.dart';
import 'package:grabbit/features/queue/data/completed_outputs.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_dimension_service.g.dart';

/// Backfills `width`/`height` for library items that predate dimension capture
/// (P10i-c). Best-effort and idempotent: images are decoded from the file
/// header, videos read their retained `.info.json` sidecar, and anything that
/// can't be resolved is simply left for the next run. Audio is excluded — it has
/// no dimensions, so it would otherwise be re-scanned on every launch.
class MediaDimensionService {
  MediaDimensionService(this._db);

  final AppDatabase _db;

  Future<void> backfillDimensions() async {
    final pending =
        await (_db.select(_db.mediaItems)..where(
              (t) => t.width.isNull() & t.type.isIn(const ['video', 'image']),
            ))
            .get();

    for (final item in pending) {
      await Future<void>.delayed(Duration.zero); // yield between items
      try {
        final dims = await _resolve(item);
        if (dims == null) continue;
        await (_db.update(
          _db.mediaItems,
        )..where((t) => t.id.equals(item.id))).write(
          MediaItemsCompanion(width: Value(dims.$1), height: Value(dims.$2)),
        );
      } catch (_) {
        // Best-effort: skip unreadable files / malformed sidecars.
      }
    }
  }

  Future<(int, int)?> _resolve(MediaItem item) async {
    final file = File(item.filePath);
    if (item.type == 'image') return readImageDimensions(file);

    // Video: the .info.json sidecar lives in the same per-task folder.
    final dir = file.parent;
    if (!dir.existsSync()) return null;
    final info = classifyDownloadOutputs(dir.listSync().whereType<File>()).info;
    if (info == null) return null;
    final parsed = parseInfoJsonString(await info.readAsString());
    if (parsed?.width == null || parsed?.height == null) return null;
    return (parsed!.width!, parsed.height!);
  }
}

@Riverpod(keepAlive: true)
MediaDimensionService mediaDimensionService(Ref ref) =>
    MediaDimensionService(ref.watch(appDatabaseProvider));
