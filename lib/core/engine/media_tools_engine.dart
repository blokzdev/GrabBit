/// On-device media-editing engine (ffmpeg). Pure-Dart contract so the Android
/// (FFmpegKit) impl and a future Windows (`ffmpeg.exe`, P8) impl stay swappable.
library;

enum ToolStage { running, done, error }

class ToolProgress {
  const ToolProgress({
    required this.stage,
    this.percent,
    this.indeterminate = false,
    this.error,
  });

  /// 0..100 when known.
  final double? percent;
  final ToolStage stage;
  final bool indeterminate;
  final String? error;

  factory ToolProgress.running(double? percent) => ToolProgress(
    stage: ToolStage.running,
    percent: percent,
    indeterminate: percent == null,
  );
  static const done = ToolProgress(stage: ToolStage.done, percent: 100);
  factory ToolProgress.failed(String error) =>
      ToolProgress(stage: ToolStage.error, error: error);
}

/// A single ffmpeg invocation: prebuilt [args], the [outputPath] it writes, and
/// the source [totalDurationMs] (for progress %; null = indeterminate).
class MediaJob {
  const MediaJob({
    required this.id,
    required this.args,
    required this.outputPath,
    this.totalDurationMs,
  });

  final String id;
  final List<String> args;
  final String outputPath;
  final int? totalDurationMs;
}

abstract interface class MediaToolsEngine {
  /// Runs [job], emitting progress then a single terminal (done/error) event.
  Stream<ToolProgress> run(MediaJob job);

  /// Cancels a running job by its id.
  Future<void> cancel(String jobId);
}

/// ffmpeg statistics `time` (ms processed) → 0..100 percent, or null when the
/// total duration is unknown (indeterminate).
double? toolPercent(int timeMs, int? totalMs) {
  if (totalMs == null || totalMs <= 0) return null;
  return (timeMs / totalMs * 100).clamp(0, 100).toDouble();
}
