import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Overwrites a file's bytes with random data before unlinking it (P9e secure
/// delete). A single pass — multi-pass overwrites are pointless on flash/SSD
/// storage with wear-levelling, where this is best-effort, not a guarantee.
/// No-op (no throw) if the file is already gone.
Future<void> secureDeleteFile(File file) async {
  if (!await file.exists()) return;
  const chunkSize = 64 * 1024;
  final rng = Random.secure();
  final raf = await file.open(mode: FileMode.write);
  try {
    var remaining = await file.length();
    final chunk = Uint8List(chunkSize);
    while (remaining > 0) {
      final n = remaining < chunkSize ? remaining : chunkSize;
      for (var i = 0; i < n; i++) {
        chunk[i] = rng.nextInt(256);
      }
      await raf.writeFrom(chunk, 0, n);
      remaining -= n;
    }
    await raf.flush();
  } finally {
    await raf.close();
  }
  await file.delete();
}
