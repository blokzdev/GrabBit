import 'package:grabbit/core/engine/download_engine.dart';

/// Windows engine backed by bundled `yt-dlp.exe` + `ffmpeg.exe` driven through
/// `Process` (see docs/ARCHITECTURE.md §2).
///
/// Stub for P0: implemented in P5 (Windows parity).
class WindowsProcessEngine implements DownloadEngine {
  const WindowsProcessEngine();

  static const _unimplemented = 'WindowsProcessEngine is implemented in P5';

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
