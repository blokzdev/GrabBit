import 'dart:io';

/// Best-effort deletion of everything directly under [dir]. Tallies the files
/// removed and bytes reclaimed. Never throws: a missing directory yields zeros
/// and individual entries that fail to delete are skipped.
Future<({int files, int bytes})> clearDirectory(Directory dir) async {
  if (!dir.existsSync()) return (files: 0, bytes: 0);
  var files = 0;
  var bytes = 0;
  for (final entry in dir.listSync()) {
    try {
      if (entry is File) {
        final size = entry.lengthSync();
        entry.deleteSync();
        files++;
        bytes += size;
      } else if (entry is Directory) {
        final contents = entry.listSync(recursive: true).whereType<File>();
        var count = 0;
        var size = 0;
        for (final f in contents) {
          try {
            size += f.lengthSync();
            count++;
          } catch (_) {}
        }
        entry.deleteSync(recursive: true);
        files += count;
        bytes += size;
      }
    } catch (_) {}
  }
  return (files: files, bytes: bytes);
}
