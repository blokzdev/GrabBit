import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/engine/pigeon/engine.pigeon.dart';

/// Free + total bytes of the volume backing a path. Used by the low-storage
/// download guard and the Storage screen (P9f). A no-op elsewhere / in tests
/// reports effectively-unlimited space so the guard never blocks.
typedef DiskSpace = ({int freeBytes, int totalBytes});

abstract class DiskSpaceService {
  Future<DiskSpace> query(String path);
}

class NoopDiskSpaceService implements DiskSpaceService {
  static const _huge = 1 << 50; // ~1 PiB

  @override
  Future<DiskSpace> query(String path) async =>
      (freeBytes: _huge, totalBytes: _huge);
}

class AndroidDiskSpaceService implements DiskSpaceService {
  final StorageHostApi _host = StorageHostApi();

  @override
  Future<DiskSpace> query(String path) async {
    final dto = await _host.diskSpace(path);
    return (freeBytes: dto.freeBytes, totalBytes: dto.totalBytes);
  }
}

final diskSpaceServiceProvider = Provider<DiskSpaceService>(
  (ref) =>
      Platform.isAndroid ? AndroidDiskSpaceService() : NoopDiskSpaceService(),
);
