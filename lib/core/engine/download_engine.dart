import 'package:grabbit/core/engine/download_error.dart';

/// Kind of media a downloaded item represents.
enum MediaType { video, audio, image }

/// Lifecycle stage of a download, mirrored from the engine.
enum DownloadStage { probing, downloading, merging, done, error, canceled }

/// A single selectable format returned by [DownloadEngine.probe].
class MediaFormat {
  const MediaFormat({
    required this.id,
    required this.ext,
    required this.label,
    required this.audioOnly,
    this.height,
    this.tbr,
    this.vcodec,
    this.acodec,
    this.filesize,
  });

  final String id;
  final String ext;
  final String label;
  final bool audioOnly;
  final int? height;
  final int? tbr;
  final String? vcodec;
  final String? acodec;
  final int? filesize;
}

/// Probe result: media metadata plus the formats available for download.
class MediaInfo {
  const MediaInfo({
    required this.title,
    required this.formats,
    this.uploader,
    this.durationSec,
    this.thumbnailUrl,
    this.site,
    this.description,
    this.uploadDate,
  });

  final String title;
  final List<MediaFormat> formats;
  final String? uploader;
  final int? durationSec;
  final String? thumbnailUrl;
  final String? site;
  final String? description;
  final String? uploadDate;
}

/// One item from an expanded playlist/channel/carousel. Shallow (from
/// `--flat-playlist`): [thumbnailUrl]/[durationSec] are often null.
class MediaEntry {
  const MediaEntry({
    required this.url,
    required this.title,
    this.id,
    this.thumbnailUrl,
    this.durationSec,
    this.isImage = false,
  });

  final String url;
  final String title;
  final String? id;
  final String? thumbnailUrl;
  final int? durationSec;
  final bool isImage;
}

/// Result of [DownloadEngine.expand]: one or more entries. A non-playlist URL
/// collapses to a single entry so callers have a uniform path.
class PlaylistInfo {
  const PlaylistInfo({
    required this.entries,
    this.id,
    this.title,
    this.isPlaylist = false,
  });

  final List<MediaEntry> entries;
  final String? id;
  final String? title;
  final bool isPlaylist;
}

/// A fully-specified download job handed to the engine.
class DownloadRequest {
  const DownloadRequest({
    required this.taskId,
    required this.url,
    required this.outputDir,
    required this.filenameTemplate,
    this.formatId,
    this.audioOnly = false,
    this.container,
    this.subtitles = false,
    this.embedThumbnail = false,
    this.embedMetadata = false,
  });

  factory DownloadRequest.fromJson(Map<String, dynamic> json) =>
      DownloadRequest(
        taskId: json['taskId'] as String,
        url: json['url'] as String,
        outputDir: json['outputDir'] as String,
        filenameTemplate: json['filenameTemplate'] as String,
        formatId: json['formatId'] as String?,
        audioOnly: json['audioOnly'] as bool? ?? false,
        container: json['container'] as String?,
        subtitles: json['subtitles'] as bool? ?? false,
        embedThumbnail: json['embedThumbnail'] as bool? ?? false,
        embedMetadata: json['embedMetadata'] as bool? ?? false,
      );

  final String taskId;
  final String url;
  final String outputDir;
  final String filenameTemplate;
  final String? formatId;
  final bool audioOnly;
  final String? container;
  final bool subtitles;
  final bool embedThumbnail;
  final bool embedMetadata;

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'url': url,
    'outputDir': outputDir,
    'filenameTemplate': filenameTemplate,
    'formatId': formatId,
    'audioOnly': audioOnly,
    'container': container,
    'subtitles': subtitles,
    'embedThumbnail': embedThumbnail,
    'embedMetadata': embedMetadata,
  };
}

/// A progress event streamed during a download. A terminal event carries a
/// [stage] of [DownloadStage.done], [DownloadStage.error], or
/// [DownloadStage.canceled].
class DownloadProgress {
  const DownloadProgress({
    required this.taskId,
    required this.stage,
    this.percent = 0,
    this.speedBps = 0,
    this.etaSec,
    this.errorCode,
  });

  final String taskId;
  final DownloadStage stage;
  final double percent;
  final double speedBps;
  final int? etaSec;
  final DownloadErrorCode? errorCode;
}

/// Versions of the bundled engine binaries.
class EngineVersion {
  const EngineVersion({required this.ytDlp, required this.ffmpeg});

  final String ytDlp;
  final String ffmpeg;
}

/// Platform-agnostic download engine. Android and Windows provide concrete
/// implementations; UI and queue code depend only on this interface
/// (see docs/ARCHITECTURE.md §2).
abstract interface class DownloadEngine {
  /// Resolves formats, metadata, and thumbnails for [url].
  Future<MediaInfo> probe(String url);

  /// Expands a URL into its entries (playlist/channel/carousel); a single item
  /// collapses to a one-entry result.
  Future<PlaylistInfo> expand(String url);

  /// Runs a download, emitting progress and a single terminal event.
  Stream<DownloadProgress> download(DownloadRequest request);

  /// Cancels an in-flight download by its task id.
  Future<void> cancel(String taskId);

  /// Reports the bundled yt-dlp/ffmpeg versions.
  Future<EngineVersion> version();

  /// Triggers a user-initiated yt-dlp self-update.
  Future<void> update();
}
