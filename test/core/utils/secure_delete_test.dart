import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/utils/secure_delete.dart';

void main() {
  test('overwrites and removes an existing file', () async {
    final dir = await Directory.systemTemp.createTemp('grabbit_secure_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/clip.mp4');
    await file.writeAsBytes(List.filled(200 * 1024, 7)); // spans >1 chunk

    await secureDeleteFile(file);

    expect(await file.exists(), isFalse);
  });

  test('is a no-op (no throw) when the file is already gone', () async {
    final dir = await Directory.systemTemp.createTemp('grabbit_secure_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/missing.mp4');

    await expectLater(secureDeleteFile(file), completes);
    expect(await file.exists(), isFalse);
  });
}
