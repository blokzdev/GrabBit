import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/storage/media_export_service.dart';
import 'package:grabbit/features/library/data/library_repository.dart';

class FakeExportService implements MediaExportService {
  String? lastTreeUri;
  String? lastFilePath;
  int calls = 0;

  @override
  Future<String?> pickFolder() async => 'content://tree/picked';

  @override
  Future<String> export({
    required String filePath,
    required String type,
    String? treeUri,
    String? subdir,
  }) async {
    calls++;
    lastFilePath = filePath;
    lastTreeUri = treeUri;
    return 'content://saved/$type';
  }
}

void main() {
  late AppDatabase db;
  late FakeExportService export;
  late LibraryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    export = FakeExportService();
    repo = LibraryRepository(db, export);
  });
  tearDown(() => db.close());

  Future<MediaItem> seed() async {
    await db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: 'i1',
            title: 'Clip',
            sourceUrl: 'https://y/i1',
            site: 'youtube',
            filePath: '/data/media/i1.mp4',
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
          ),
        );
    return (db.select(
      db.mediaItems,
    )..where((t) => t.id.equals('i1'))).getSingle();
  }

  test('export copies the file and flips storage_state to exported', () async {
    final item = await seed();
    final uri = await repo.export(item, treeUri: 'content://tree/abc');

    expect(export.calls, 1);
    expect(export.lastFilePath, '/data/media/i1.mp4');
    expect(export.lastTreeUri, 'content://tree/abc');
    expect(uri, 'content://saved/video');

    final updated = await (db.select(
      db.mediaItems,
    )..where((t) => t.id.equals('i1'))).getSingle();
    expect(updated.storageState, 'exported');
  });

  test('deleteItem removes the files and the row (cascade)', () async {
    final dir = Directory.systemTemp.createTempSync('grabbit_del');
    addTearDown(() => dir.deleteSync(recursive: true));
    final media = File('${dir.path}/clip.mp4')..writeAsStringSync('x');
    final thumb = File('${dir.path}/clip.jpg')..writeAsStringSync('t');
    await db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: 'd1',
            title: 'Clip',
            sourceUrl: 'https://y/d1',
            site: 'youtube',
            filePath: media.path,
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
            thumbPath: Value(thumb.path),
          ),
        );
    await db
        .into(db.mediaMetadata)
        .insert(const MediaMetadataCompanion(itemId: Value('d1')));
    final item = await (db.select(
      db.mediaItems,
    )..where((t) => t.id.equals('d1'))).getSingle();

    await repo.deleteItem(item);

    expect(media.existsSync(), isFalse);
    expect(thumb.existsSync(), isFalse);
    expect(await db.select(db.mediaItems).get(), isEmpty);
    expect(await db.select(db.mediaMetadata).get(), isEmpty); // cascaded
  });

  test('deleteItem(secure: true) overwrites then removes the file', () async {
    final dir = Directory.systemTemp.createTempSync('grabbit_secdel');
    addTearDown(() => dir.deleteSync(recursive: true));
    final media = File('${dir.path}/clip.mp4')..writeAsStringSync('secret');
    await db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: 's1',
            title: 'Clip',
            sourceUrl: 'https://y/s1',
            site: 'youtube',
            filePath: media.path,
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
          ),
        );
    final item = await (db.select(
      db.mediaItems,
    )..where((t) => t.id.equals('s1'))).getSingle();

    await repo.deleteItem(item, secure: true);

    expect(media.existsSync(), isFalse);
    expect(await db.select(db.mediaItems).get(), isEmpty);
  });
}
