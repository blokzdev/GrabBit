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
}
