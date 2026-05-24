import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/library/data/dedupe_service.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('grabbit_hash'));
  tearDown(() => dir.deleteSync(recursive: true));

  File write(String name, List<int> bytes) =>
      File('${dir.path}/$name')..writeAsBytesSync(bytes);

  test('identical content hashes the same; different content differs', () {
    final a = write('a.bin', List.filled(2048, 7));
    final b = write('b.bin', List.filled(2048, 7));
    final c = write('c.bin', List.filled(2048, 9));

    final hashes = hashFilesSync([a.path, b.path, c.path]);
    expect(hashes[a.path], isNotNull);
    expect(hashes[a.path], hashes[b.path]);
    expect(hashes[a.path], isNot(hashes[c.path]));
  });

  test('same bytes but different size hash differently', () {
    final a = write('a.bin', List.filled(100, 1));
    final b = write('b.bin', List.filled(200, 1));
    final hashes = hashFilesSync([a.path, b.path]);
    expect(hashes[a.path], isNot(hashes[b.path]));
  });

  test('missing files are skipped', () {
    final a = write('a.bin', [1, 2, 3]);
    final hashes = hashFilesSync([a.path, '${dir.path}/nope.bin']);
    expect(hashes.keys, [a.path]);
  });
}
