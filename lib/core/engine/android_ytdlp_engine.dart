import 'package:grabbit/core/engine/download_engine.dart';

/// Android engine backed by youtubedl-android via Pigeon (see pigeons/engine.dart).
///
/// Stub for P0: the architecture wires the engine selection now; the native
/// bridge is implemented in P1.
class AndroidYtDlpEngine implements DownloadEngine {
  const AndroidYtDlpEngine();

  static const _unimplemented = 'AndroidYtDlpEngine is implemented in P1';

  @override
  Future<MediaInfo> probe(String url) =>
      throw UnimplementedError(_unimplemented);

  @override
  Stream<DownloadProgress> download(DownloadRequest request) =>
      throw UnimplementedError(_unimplemented);

  @override
  Future<void> cancel(String taskId) =>
      throw UnimplementedError(_unimplemented);

  @override
  Future<EngineVersion> version() => throw UnimplementedError(_unimplemented);

  @override
  Future<void> update() => throw UnimplementedError(_unimplemented);
}
