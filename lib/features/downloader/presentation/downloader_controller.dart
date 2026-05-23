import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/download_error.dart';
import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:grabbit/core/storage/media_storage.dart';
import 'package:grabbit/core/utils/task_id.dart';
import 'package:grabbit/features/downloader/data/download_request_builder.dart';
import 'package:grabbit/features/downloader/presentation/selection_controller.dart';
import 'package:grabbit/features/queue/data/queued_download.dart';
import 'package:grabbit/features/queue/presentation/queue_controller.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'downloader_controller.g.dart';

enum DownloaderPhase { idle, probing, ready }

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
    this.errorCode,
  });

  final DownloaderPhase phase;
  final String url;
  final MediaInfo? info;
  final String? errorMessage;
  final DownloadErrorCode? errorCode;

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

  /// Expands [rawUrl] to detect a playlist/carousel. [expand] is a fast,
  /// flat listing (cheap on a real playlist); if it yields multiple entries we
  /// hand them to the selection picker and return true. A single entry isn't a
  /// playlist, so we fall through to the slower [probe] for the rich
  /// single-item preview (formats, thumbnail) and return false.
  Future<bool> checkSingle(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return false;
    state = DownloaderState(phase: DownloaderPhase.probing, url: url);
    try {
      final info = await ref.read(downloadEngineProvider).expand(url);
      if (info.entries.length > 1) {
        ref.read(selectionControllerProvider.notifier).setSources([
          ExpandedSource(
            url: url,
            entries: info.entries,
            playlistId: info.id,
            playlistTitle: info.title,
          ),
        ]);
        state = const DownloaderState();
        return true;
      }
    } on DownloadException catch (e) {
      state = DownloaderState(
        phase: DownloaderPhase.idle,
        url: url,
        errorCode: e.code,
        errorMessage: e.message,
      );
      return false;
    }
    await probe(url);
    return false;
  }

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
        errorCode: e.code,
      );
    }
  }

  /// Builds the request from the probed info + chosen preset and adds it to the
  /// download queue. With [startNow] the scheduler runs it immediately;
  /// otherwise it's held until the user taps "Start all" on the queue screen.
  Future<void> enqueue(QualityPreset preset, {bool startNow = true}) async {
    final current = state;
    final info = current.info;
    if (info == null) return;

    final taskId = newTaskId();
    final dir = await ref.read(mediaStorageProvider).mediaDirectory();
    final settings = await ref.read(settingsControllerProvider.future);
    final request = buildDownloadRequest(
      taskId: taskId,
      url: current.url,
      outputDir: dir.path,
      settings: settings,
      audioOnly: preset.audioOnly,
      formatSelector: preset.formatSelector,
    );
    final download = QueuedDownload(
      request: request,
      title: info.title,
      site: info.site,
      durationSec: info.durationSec,
      uploader: info.uploader,
      originalUrl: current.url,
      description: info.description,
      uploadDate: info.uploadDate,
    );
    final queue = ref.read(queueControllerProvider.notifier);
    if (startNow) {
      await queue.enqueue(download);
    } else {
      await queue.enqueueHeld([download]);
    }
    // Clear the form; the UI navigates away after enqueuing.
    state = const DownloaderState();
  }
}
