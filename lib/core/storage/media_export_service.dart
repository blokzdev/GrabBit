import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/engine/pigeon/engine.pigeon.dart';

/// Exports a private library file to the device — a user-picked SAF folder when
/// one is configured, otherwise the gallery-visible MediaStore default.
abstract class MediaExportService {
  /// Opens the system folder picker; returns the persisted tree URI or null.
  Future<String?> pickFolder();

  Future<String> export({
    required String filePath,
    required String type,
    String? treeUri,
    String? subdir,
  });
}

class NoopMediaExportService implements MediaExportService {
  @override
  Future<String?> pickFolder() async => null;
  @override
  Future<String> export({
    required String filePath,
    required String type,
    String? treeUri,
    String? subdir,
  }) async => '';
}

class AndroidMediaExportService implements MediaExportService {
  final StorageHostApi _host = StorageHostApi();

  @override
  Future<String?> pickFolder() => _host.pickExportFolder();

  @override
  Future<String> export({
    required String filePath,
    required String type,
    String? treeUri,
    String? subdir,
  }) {
    if (treeUri != null && treeUri.isNotEmpty) {
      return _host.exportToTree(filePath, treeUri, type, subdir);
    }
    return _host.exportToMediaStore(filePath, type, subdir);
  }
}

final mediaExportServiceProvider = Provider<MediaExportService>(
  (ref) => Platform.isAndroid
      ? AndroidMediaExportService()
      : NoopMediaExportService(),
);
