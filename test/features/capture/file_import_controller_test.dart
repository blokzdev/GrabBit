import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/capture/capture_commit_service.dart';
import 'package:grabbit/core/things/thing_repository.dart';
import 'package:grabbit/features/capture/presentation/file_import_controller.dart';

void main() {
  late AppDatabase db;
  late ThingRepository things;
  late Directory tmp;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    things = ThingRepository(db);
    tmp = await Directory.systemTemp.createTemp('grabbit_import_test');
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  DefaultFileImportController controller({
    Future<PickedFile?> Function()? pickFile,
  }) => DefaultFileImportController(
    db,
    CaptureCommitService(things),
    () async => Directory('${tmp.path}/dest')..createSync(recursive: true),
    pickFile: pickFile,
    now: () => DateTime.utc(2026, 6, 15),
    newId: () => 'local_test',
  );

  Future<String> writeSource(String name, String content) async {
    final f = File('${tmp.path}/$name');
    await f.writeAsString(content);
    return f.path;
  }

  test('a media file is imported as a MediaItem', () async {
    final src = await writeSource('photo.jpg', 'not-a-real-image');

    final result = await controller().importFile(
      sourcePath: src,
      fileName: 'photo.jpg',
    );

    expect(result, isA<FileImportedMedia>());
    expect((result as FileImportedMedia).type, 'image');
    final items = await db.select(db.mediaItems).get();
    expect(items, hasLength(1));
    expect(items.single.id, 'local_test');
    expect(items.single.type, 'image');
    expect(items.single.title, 'photo'); // extension stripped
    expect(File(items.single.filePath).existsSync(), isTrue);
    // No generic Thing asserted directly (projection handles MediaObjects).
    expect(await things.countThings(), 0);
  });

  test('a non-media file is asserted as a DigitalDocument Thing', () async {
    final src = await writeSource('report.pdf', '%PDF-1.4 fake');

    final result = await controller().importFile(
      sourcePath: src,
      fileName: 'report.pdf',
    );

    expect(result, isA<FileImportedThing>());
    expect(await db.select(db.mediaItems).get(), isEmpty);
    expect(await things.countThings(), 1);
    final thing = await things.thingById((result as FileImportedThing).thingId);
    expect(thing!.type, 'DigitalDocument');
    expect(thing.jsonld, contains('application/pdf'));
  });

  test('pickAndImport returns null when cancelled', () async {
    final result = await controller(pickFile: () async => null).pickAndImport();
    expect(result, isNull);
  });

  test('a missing source surfaces an error', () async {
    final result = await controller().importFile(
      sourcePath: '${tmp.path}/does-not-exist.png',
      fileName: 'does-not-exist.png',
    );
    expect(result, isA<FileImportError>());
  });
}
