import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/share/external_share_service.dart';
import 'package:grabbit/features/library/data/thing_export_service.dart';

class _FakeShare implements ExternalShareService {
  final List<List<String>> sharedFiles = [];
  final List<String> sharedText = [];
  final List<String> openedUrls = [];

  @override
  Future<void> shareFiles(List<String> paths) async => sharedFiles.add(paths);
  @override
  Future<void> shareText(String text, {String? subject}) async =>
      sharedText.add(text);
  @override
  Future<void> openUrl(String url) async => openedUrls.add(url);
}

Thing _thing(String type, String jsonld) => Thing(
  id: 'thing_1',
  type: type,
  jsonld: jsonld,
  name: 'X',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  late _FakeShare share;
  late Directory tmp;
  late ThingExportService service;

  setUp(() async {
    share = _FakeShare();
    tmp = await Directory.systemTemp.createTemp('grabbit_export_test');
    service = ThingExportService(
      share,
      tempDir: () async => tmp,
      now: () => DateTime.utc(2026),
    );
  });
  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('a Recipe exports as shared text', () async {
    await service.export(
      _thing(
        'Recipe',
        '{"@type":"Recipe","name":"Soup","recipeIngredient":["water"]}',
      ),
    );
    expect(share.sharedText, hasLength(1));
    expect(share.sharedText.single, contains('Soup'));
    expect(share.sharedFiles, isEmpty);
  });

  test('a Place exports as a geo: deep link', () async {
    await service.export(
      _thing('Place', '{"@type":"Place","name":"Cafe","address":"1 Main St"}'),
    );
    expect(share.openedUrls, hasLength(1));
    expect(share.openedUrls.single, startsWith('geo:0,0?q='));
  });

  test('an Event writes and shares a .ics file', () async {
    await service.export(
      _thing(
        'Event',
        '{"@type":"Event","name":"Conf","startDate":"2026-06-20T09:00:00Z"}',
      ),
    );
    expect(share.sharedFiles, hasLength(1));
    final path = share.sharedFiles.single.single;
    expect(path, endsWith('.ics'));
    expect(File(path).existsSync(), isTrue);
    expect(await File(path).readAsString(), contains('BEGIN:VEVENT'));
  });

  test('a long-tail type exports nothing', () async {
    await service.export(_thing('Book', '{"@type":"Book","name":"B"}'));
    expect(share.sharedText, isEmpty);
    expect(share.sharedFiles, isEmpty);
    expect(share.openedUrls, isEmpty);
  });
}
