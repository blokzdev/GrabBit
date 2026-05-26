import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/data/media_dimension_service.dart';
import 'package:image/image.dart' as img;

void main() {
  late AppDatabase db;
  late MediaDimensionService service;
  late Directory tmp;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = MediaDimensionService(db);
    tmp = Directory.systemTemp.createTempSync('grabbit_dims_test');
  });
  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> seed(String id, String type, String filePath, {int? width}) => db
      .into(db.mediaItems)
      .insert(
        MediaItemsCompanion.insert(
          id: id,
          title: id,
          sourceUrl: 'https://x/$id',
          site: 'test',
          filePath: filePath,
          type: type,
          createdAt: DateTime.utc(2026),
          storageState: 'private',
          width: Value(width),
        ),
      );

  Future<MediaItem> read(String id) =>
      (db.select(db.mediaItems)..where((t) => t.id.equals(id))).getSingle();

  test('backfills image dimensions by decoding the file', () async {
    final imgFile = File('${tmp.path}/pic.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 800, height: 600)));
    await seed('img1', 'image', imgFile.path);

    await service.backfillDimensions();

    final item = await read('img1');
    expect(item.width, 800);
    expect(item.height, 600);
  });

  test('backfills video dimensions from the .info.json sidecar', () async {
    final dir = Directory('${tmp.path}/task1')..createSync();
    File('${dir.path}/clip.mp4').writeAsStringSync('not really a video');
    File(
      '${dir.path}/clip.info.json',
    ).writeAsStringSync(jsonEncode({'width': 1280, 'height': 720}));
    await seed('vid1', 'video', '${dir.path}/clip.mp4');

    await service.backfillDimensions();

    final item = await read('vid1');
    expect(item.width, 1280);
    expect(item.height, 720);
  });

  test('leaves audio items and already-filled items untouched', () async {
    await seed('aud1', 'audio', '${tmp.path}/song.m4a');
    await seed('img2', 'image', '${tmp.path}/missing.png', width: 100);

    await service.backfillDimensions();

    expect((await read('aud1')).width, isNull);
    // Already had a width → not re-scanned (file doesn't even exist).
    expect((await read('img2')).width, 100);
  });

  test('skips items whose files or sidecars are unavailable', () async {
    await seed('img3', 'image', '${tmp.path}/gone.png');
    await seed('vid2', 'video', '${tmp.path}/no_sidecar/clip.mp4');

    await service.backfillDimensions(); // must not throw

    expect((await read('img3')).width, isNull);
    expect((await read('vid2')).width, isNull);
  });
}
