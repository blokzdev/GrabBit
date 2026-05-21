import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/data/folder_repository.dart';

void main() {
  late AppDatabase db;
  late FolderRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FolderRepository(db);
  });
  tearDown(() => db.close());

  Future<void> seedItem(String id, {int? folderId}) => db
      .into(db.mediaItems)
      .insert(
        MediaItemsCompanion.insert(
          id: id,
          title: id,
          sourceUrl: 'u',
          site: 's',
          filePath: '/m/$id',
          type: 'video',
          createdAt: DateTime.utc(2026),
          storageState: 'private',
          folderId: Value(folderId),
        ),
      );

  test('create + nested subfolders + breadcrumb', () async {
    final music = await repo.createFolder('Music');
    final rock = await repo.createFolder('Rock', parentId: music);

    expect((await repo.watchSubfolders(null).first).map((f) => f.name), [
      'Music',
    ]);
    expect((await repo.watchSubfolders(music).first).map((f) => f.name), [
      'Rock',
    ]);

    final crumbs = await repo.breadcrumb(rock);
    expect(crumbs.map((f) => f.name), ['Music', 'Rock']);
  });

  test('rename folder', () async {
    final id = await repo.createFolder('Old');
    await repo.renameFolder(id, 'New');
    expect((await repo.folderById(id))!.name, 'New');
  });

  test('moveItems sets folderId; items query is folder-scoped', () async {
    final f = await repo.createFolder('Clips');
    await seedItem('a');
    await seedItem('b');

    expect((await repo.watchItemsInFolder(null).first).length, 2);
    await repo.moveItems(['a'], f);

    expect((await repo.watchItemsInFolder(f).first).map((i) => i.id), ['a']);
    expect((await repo.watchItemsInFolder(null).first).map((i) => i.id), ['b']);
  });

  test(
    'deleting a folder orphans its media + subfolders to the root',
    () async {
      final parent = await repo.createFolder('Parent');
      final child = await repo.createFolder('Child', parentId: parent);
      await seedItem('x', folderId: parent);

      await repo.deleteFolder(parent);

      // Child reparents to root; item falls back to root (folderId null).
      expect((await repo.folderById(child))!.parentId, isNull);
      final item = await (db.select(
        db.mediaItems,
      )..where((t) => t.id.equals('x'))).getSingle();
      expect(item.folderId, isNull);
    },
  );
}
