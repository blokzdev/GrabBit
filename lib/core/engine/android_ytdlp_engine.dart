import 'package:flutter/services.dart' show PlatformException;
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/download_error.dart';
import 'package:grabbit/core/engine/error_mapping.dart';
import 'package:grabbit/core/engine/pigeon/engine.pigeon.dart';
import 'package:grabbit/core/engine/pigeon/mappers.dart';

/// Android engine backed by youtubedl-android via Pigeon → Kotlin.
/// Download/cancel land in P1 chunk 3.
class AndroidYtDlpEngine implements DownloadEngine {
  AndroidYtDlpEngine() : _host = YtDlpHostApi();

  final YtDlpHostApi _host;

  @override
  Future<MediaInfo> probe(String url) async {
    try {
      final dto = await _host.probe(url);
      return dto.toDomain();
    } on PlatformException catch (e) {
      throw DownloadException(
        classifyEngineError(e.message),
        e.message ?? 'Failed to read media info',
        cause: e,
      );
    }
  }

  @override
  Future<EngineVersion> version() async {
    final ytDlp = await _host.engineVersions();
    return EngineVersion(ytDlp: ytDlp, ffmpeg: 'bundled');
  }

  @override
  Future<void> update() => _host.updateEngine();

  @override
  Stream<DownloadProgress> download(DownloadRequest request) =>
      throw UnimplementedError('Download is implemented in P1 chunk 3');

  @override
  Future<void> cancel(String taskId) =>
      throw UnimplementedError('Cancel is implemented in P1 chunk 3');
}
