import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/download_error.dart';
import 'package:grabbit/core/engine/error_mapping.dart';
import 'package:grabbit/core/engine/pigeon/engine.pigeon.dart';
import 'package:grabbit/core/engine/pigeon/mappers.dart';

/// Android engine backed by youtubedl-android via Pigeon → Kotlin. Progress is
/// pushed back through [YtDlpFlutterApi.onProgress] and fanned out to a
/// per-task [Stream].
class AndroidYtDlpEngine implements DownloadEngine, YtDlpFlutterApi {
  AndroidYtDlpEngine() : _host = YtDlpHostApi() {
    YtDlpFlutterApi.setUp(this);
  }

  final YtDlpHostApi _host;
  final Map<String, StreamController<DownloadProgress>> _controllers = {};

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
  Stream<DownloadProgress> download(DownloadRequest request) {
    final controller = StreamController<DownloadProgress>();
    _controllers[request.taskId] = controller;
    // startDownload is fire-and-forget; progress + terminal events arrive via
    // onProgress. Surface a launch failure as a terminal error event.
    _host.startDownload(request.toDto()).catchError((Object e) {
      _emit(
        DownloadProgress(
          taskId: request.taskId,
          stage: DownloadStage.error,
          errorCode: e is PlatformException
              ? classifyEngineError(e.message)
              : DownloadErrorCode.unknown,
        ),
      );
    });
    return controller.stream;
  }

  @override
  Future<void> cancel(String taskId) => _host.cancel(taskId);

  @override
  Future<EngineVersion> version() async {
    final ytDlp = await _host.engineVersions();
    return EngineVersion(ytDlp: ytDlp, ffmpeg: 'bundled');
  }

  @override
  Future<void> update() => _host.updateEngine();

  @override
  void onProgress(ProgressDto progress) => _emit(progress.toDomain());

  void _emit(DownloadProgress progress) {
    final controller = _controllers[progress.taskId];
    if (controller == null || controller.isClosed) return;
    controller.add(progress);
    if (_isTerminal(progress.stage)) {
      controller.close();
      _controllers.remove(progress.taskId);
    }
  }

  static bool _isTerminal(DownloadStage stage) =>
      stage == DownloadStage.done ||
      stage == DownloadStage.error ||
      stage == DownloadStage.canceled;
}
