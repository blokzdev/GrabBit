import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:grabbit/core/engine/media_tools_engine.dart';

/// [MediaToolsEngine] backed by ffmpeg_kit_flutter_new. Progress comes from the
/// statistics callback (processed time / source duration); jobs are cancelable
/// via the kept session.
class AndroidFfmpegToolsEngine implements MediaToolsEngine {
  final Map<String, FFmpegSession> _sessions = {};

  @override
  Stream<ToolProgress> run(MediaJob job) {
    final controller = StreamController<ToolProgress>();
    FFmpegKit.executeWithArgumentsAsync(
      job.args,
      (session) async {
        _sessions.remove(job.id);
        final code = await session.getReturnCode();
        if (ReturnCode.isSuccess(code)) {
          controller.add(ToolProgress.done);
        } else if (ReturnCode.isCancel(code)) {
          controller.add(ToolProgress.failed('Canceled'));
        } else {
          controller.add(ToolProgress.failed('Editing failed'));
        }
        await controller.close();
      },
      null,
      (stats) => controller.add(
        ToolProgress.running(toolPercent(stats.getTime(), job.totalDurationMs)),
      ),
    ).then((session) => _sessions[job.id] = session);
    return controller.stream;
  }

  @override
  Future<void> cancel(String jobId) async => _sessions[jobId]?.cancel();
}
