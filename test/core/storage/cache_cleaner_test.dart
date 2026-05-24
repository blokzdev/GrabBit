import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/storage/cache_cleaner.dart';

void main() {
  group('clearDirectory', () {
    late Directory dir;

    setUp(
      () => dir = Directory.systemTemp.createTempSync('grabbit_cache_test'),
    );
    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('deletes files and reports count + bytes', () async {
      File('${dir.path}/a.tmp').writeAsBytesSync(List.filled(100, 0));
      File('${dir.path}/b.tmp').writeAsBytesSync(List.filled(50, 0));
      final sub = Directory('${dir.path}/nested')..createSync();
      File('${sub.path}/c.tmp').writeAsBytesSync(List.filled(25, 0));

      final result = await clearDirectory(dir);

      expect(result.files, 3);
      expect(result.bytes, 175);
      expect(dir.listSync(), isEmpty);
    });

    test('returns zeros for an empty directory', () async {
      final result = await clearDirectory(dir);
      expect(result.files, 0);
      expect(result.bytes, 0);
    });

    test('returns zeros (no throw) for a missing directory', () async {
      final missing = Directory('${dir.path}/does_not_exist');
      final result = await clearDirectory(missing);
      expect(result.files, 0);
      expect(result.bytes, 0);
    });
  });
}
