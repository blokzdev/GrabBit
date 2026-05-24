import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/storage/media_storage.dart';
import 'package:grabbit/features/library/data/storage_maintenance.dart';

/// MediaStorage pointed at a test temp dir (no path_provider plugin in tests).
class _FakeStorage extends MediaStorage {
  _FakeStorage(this._dir);
  final Directory _dir;
  @override
  Future<Directory> mediaDirectory() async => _dir;
}

void main() {
  late AppDatabase db;
  late Directory root;
  late StorageMaintenance maintenance;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    root = Directory.systemTemp.createTempSync('grabbit_maint_');
    maintenance = StorageMaintenance(db, _FakeStorage(root));
  });
  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('deletes only unreferenced files and prunes empty dirs', () async {
    // A referenced item with its file on disk.
    final keepDir = Directory('${root.path}/keep')..createSync();
    final keep = File('${keepDir.path}/clip.mp4')..writeAsStringSync('keep');
    await db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: 'k1',
            title: 'Keep',
            sourceUrl: 'https://y/k1',
            site: 'youtube',
            filePath: keep.path,
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
          ),
        );

    // Orphans: a stray file + a whole leftover folder, none in the DB.
    final orphan = File('${root.path}/orphan.mp4')
      ..writeAsBytesSync(List.filled(2048, 1));
    final orphanDir = Directory('${root.path}/gone')..createSync();
    final orphan2 = File('${orphanDir.path}/old.mp4')
      ..writeAsBytesSync(List.filled(1024, 1));

    final result = await maintenance.cleanupOrphans();

    expect(result.files, 2);
    expect(result.bytes, 3072);
    expect(keep.existsSync(), isTrue); // referenced → kept
    expect(orphan.existsSync(), isFalse);
    expect(orphan2.existsSync(), isFalse);
    expect(orphanDir.existsSync(), isFalse); // emptied → pruned
  });

  test('reports zero when there is nothing to clean', () async {
    final result = await maintenance.cleanupOrphans();
    expect(result.files, 0);
    expect(result.bytes, 0);
  });

  test('also keeps referenced thumbnails', () async {
    final thumb = File('${root.path}/t.jpg')..writeAsStringSync('t');
    await db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: 'k2',
            title: 'Keep',
            sourceUrl: 'https://y/k2',
            site: 'youtube',
            filePath: '${root.path}/v.mp4',
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
            thumbPath: Value(thumb.path),
          ),
        );
    File('${root.path}/v.mp4').writeAsStringSync('v');

    final result = await maintenance.cleanupOrphans();
    expect(result.files, 0);
    expect(thumb.existsSync(), isTrue);
  });
}
