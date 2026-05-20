import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_storage.g.dart';

/// Resolves the app-private media directory. Files here live in app-specific
/// storage (no permission, not gallery-indexed) — the private library space.
class MediaStorage {
  Future<Directory> mediaDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/media');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}

@Riverpod(keepAlive: true)
MediaStorage mediaStorage(Ref ref) => MediaStorage();
