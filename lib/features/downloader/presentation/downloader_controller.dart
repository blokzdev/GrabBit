import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/download_error.dart';
import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:grabbit/core/storage/media_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'downloader_controller.g.dart';

enum DownloaderPhase { idle, probing, ready, downloading, done }

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
    this.progress,
    this.errorMessage,
  });

  final DownloaderPhase phase;
  final String url;
  final MediaInfo? info;
  final DownloadProgress? progress;
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

  Future<void> startDownload(QualityPreset preset) async {
    final current = state;
    final info = current.info;
    if (info == null || current.phase == DownloaderPhase.downloading) return;

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

    final engine = ref.read(downloadEngineProvider);
    try {
      await for (final p in engine.download(request)) {
        state = DownloaderState(
          phase: DownloaderPhase.downloading,
          url: current.url,
          info: info,
          progress: p,
        );
        switch (p.stage) {
          case DownloadStage.done:
            await _persist(
              taskId: taskId,
              info: info,
              url: current.url,
              dir: dir,
              audioOnly: preset.audioOnly,
            );
            state = DownloaderState(
              phase: DownloaderPhase.done,
              url: current.url,
              info: info,
              progress: p,
            );
          case DownloadStage.error:
            state = DownloaderState(
              phase: DownloaderPhase.ready,
              url: current.url,
              info: info,
              errorMessage:
                  'Download failed (${p.errorCode?.name ?? 'unknown'})',
            );
          case DownloadStage.canceled:
            state = DownloaderState(
              phase: DownloaderPhase.ready,
              url: current.url,
              info: info,
              errorMessage: 'Canceled',
            );
          case DownloadStage.probing:
          case DownloadStage.downloading:
          case DownloadStage.merging:
            break;
        }
      }
    } catch (e) {
      state = DownloaderState(
        phase: DownloaderPhase.ready,
        url: current.url,
        info: info,
        errorMessage: '$e',
      );
    }
  }

  Future<void> cancel() async {
    final taskId = state.progress?.taskId;
    if (taskId != null) {
      await ref.read(downloadEngineProvider).cancel(taskId);
    }
  }

  void reset() => state = const DownloaderState();

  Future<void> _persist({
    required String taskId,
    required MediaInfo info,
    required String url,
    required Directory dir,
    required bool audioOnly,
  }) async {
    File? thumb;
    File? media;
    for (final entry in dir.listSync().whereType<File>()) {
      if (!entry.uri.pathSegments.last.startsWith('$taskId.')) continue;
      if (entry.path.toLowerCase().endsWith('.jpg')) {
        thumb = entry;
      } else {
        media = entry;
      }
    }
    if (media == null) return;

    final ext = media.path.split('.').last.toLowerCase();
    final db = ref.read(appDatabaseProvider);
    await db
        .into(db.mediaItems)
        .insertOnConflictUpdate(
          MediaItemsCompanion.insert(
            id: taskId,
            title: info.title,
            sourceUrl: url,
            site: info.site ?? 'unknown',
            filePath: media.path,
            type: audioOnly ? 'audio' : _typeForExt(ext),
            createdAt: DateTime.now(),
            storageState: 'private',
            durationSec: Value(info.durationSec),
            sizeBytes: Value(await media.length()),
            thumbPath: Value(thumb?.path),
          ),
        );
  }
}

String _typeForExt(String ext) {
  const image = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
  const audio = {'m4a', 'mp3', 'opus', 'aac', 'ogg', 'wav'};
  if (image.contains(ext)) return 'image';
  if (audio.contains(ext)) return 'audio';
  return 'video';
}
