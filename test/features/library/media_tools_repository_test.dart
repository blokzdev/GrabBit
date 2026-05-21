import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/data/media_tools_repository.dart';

void main() {
  late AppDatabase db;
  late MediaToolsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = MediaToolsRepository(db);
  });
  tearDown(() => db.close());

  Future<MediaItem> seedSource() async {
    final folderId = await db
        .into(db.folders)
        .insert(
          FoldersCompanion.insert(name: 'F', createdAt: DateTime.utc(2026)),
        );
    await db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: 'src',
            title: 'Original',
            sourceUrl: 'https://y/v',
            site: 'youtube',
            filePath: '/m/src/v.mp4',
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
            folderId: Value(folderId),
          ),
        );
    return (db.select(
      db.mediaItems,
    )..where((t) => t.id.equals('src'))).getSingle();
  }

  test(
    'saveEdited inserts a new item inheriting folder + source url',
    () async {
      final source = await seedSource();
      await repo.saveEdited(
        id: 'edit1',
        source: source,
        title: 'Original (trim)',
        outputPath: '/m/edit1/trim.mp4',
        durationSec: 10,
        sizeBytes: 1234,
      );

      final edited = await (db.select(
        db.mediaItems,
      )..where((t) => t.id.equals('edit1'))).getSingle();
      expect(edited.title, 'Original (trim)');
      expect(edited.type, 'video');
      expect(edited.filePath, '/m/edit1/trim.mp4');
      expect(edited.folderId, source.folderId); // inherits the source's folder
      expect(edited.sourceUrl, 'https://y/v');
      expect(edited.durationSec, 10);

      // The original is untouched (two rows now).
      expect((await db.select(db.mediaItems).get()).length, 2);
    },
  );

  test('infers image type from a frame output extension', () async {
    final source = await seedSource();
    await repo.saveEdited(
      id: 'frame1',
      source: source,
      title: 'Original (frame)',
      outputPath: '/m/frame1/frame.jpg',
    );
    final edited = await (db.select(
      db.mediaItems,
    )..where((t) => t.id.equals('frame1'))).getSingle();
    expect(edited.type, 'image');
  });
}
