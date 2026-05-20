import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/download_error.dart';
import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:grabbit/core/storage/media_storage.dart';
import 'package:grabbit/features/queue/data/queued_download.dart';
import 'package:grabbit/features/queue/presentation/queue_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'downloader_controller.g.dart';

enum DownloaderPhase { idle, probing, ready, queued }

/// Quality presets exposed in P1. The selector strings are yt-dlp `-f`
/// expressions, so they work without inspecting the probed format ids.
enum QualityPreset {
  best('Best', null, false),
  p1080('1080p', 'bestvideo[height<=1080]+bestaudio/best[height<=1080]', false),
  p720('720p', 'bestvideo[height<=720]+bestaudio/best[height<=720]', false),
  audio('Audio only', null, true);

  const QualityPreset(this.label, this.formatSelector, this.audioOnly);

  final String label;
  final String? formatSelector;
  final bool audioOnly;
}

class DownloaderState {
  const DownloaderState({
    this.phase = DownloaderPhase.idle,
    this.url = '',
    this.info,
    this.errorMessage,
  });

  final DownloaderPhase phase;
  final String url;
  final MediaInfo? info;
  final String? errorMessage;

  /// Presets worth showing, given the heights the source actually offers.
  List<QualityPreset> get availablePresets {
    final maxHeight = info?.formats.fold<int>(
      0,
      (m, f) => (f.height ?? 0) > m ? (f.height ?? 0) : m,
    );
    return [
      QualityPreset.best,
      if ((maxHeight ?? 0) >= 1080) QualityPreset.p1080,
      if ((maxHeight ?? 0) >= 720) QualityPreset.p720,
      QualityPreset.audio,
    ];
  }
}

@riverpod
class DownloaderController extends _$DownloaderController {
  @override
  DownloaderState build() => const DownloaderState();

  Future<void> probe(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return;
    state = DownloaderState(phase: DownloaderPhase.probing, url: url);
    try {
      final info = await ref.read(downloadEngineProvider).probe(url);
      state = DownloaderState(
        phase: DownloaderPhase.ready,
        url: url,
        info: info,
      );
    } on DownloadException catch (e) {
      state = DownloaderState(
        phase: DownloaderPhase.idle,
        url: url,
        errorMessage: e.message,
      );
    }
  }

  /// Builds the request from the probed info + chosen preset and adds it to the
  /// download queue (progress is then shown on the queue screen).
  Future<void> enqueue(QualityPreset preset) async {
    final current = state;
    final info = current.info;
    if (info == null) return;

    final taskId = 'dl_${DateTime.now().microsecondsSinceEpoch}';
    final dir = await ref.read(mediaStorageProvider).mediaDirectory();
    final request = DownloadRequest(
      taskId: taskId,
      url: current.url,
      outputDir: dir.path,
      filenameTemplate: '%(title)s.%(ext)s',
      formatId: preset.formatSelector,
      audioOnly: preset.audioOnly,
      container: preset.audioOnly ? 'm4a' : 'mp4',
      embedThumbnail: true,
      embedMetadata: true,
    );
    await ref
        .read(queueControllerProvider.notifier)
        .enqueue(
          QueuedDownload(
            request: request,
            title: info.title,
            site: info.site,
            durationSec: info.durationSec,
            uploader: info.uploader,
            originalUrl: current.url,
          ),
        );
    state = DownloaderState(
      phase: DownloaderPhase.queued,
      url: current.url,
      info: info,
    );
  }

  void reset() => state = const DownloaderState();
}
