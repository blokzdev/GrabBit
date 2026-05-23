// Pigeon definition for the Android download engine bridge (docs/SPEC.md §2).
//
// Generate with:
//   dart run pigeon --input pigeons/engine.dart
//
// Generation is wired up in P1 alongside the youtubedl-android integration.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/engine/pigeon/engine.pigeon.dart',
    kotlinOut:
        'android/app/src/main/kotlin/dev/blokz/grabbit/EnginePigeon.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.blokz.grabbit'),
    dartPackageName: 'grabbit',
  ),
)
class FormatDto {
  FormatDto({
    required this.id,
    required this.ext,
    required this.audioOnly,
    required this.label,
    this.height,
    this.tbr,
    this.vcodec,
    this.acodec,
    this.filesize,
  });

  String id;
  String ext;
  int? height;
  int? tbr;
  String? vcodec;
  String? acodec;
  bool audioOnly;
  int? filesize;
  String label;
}

class MediaInfoDto {
  MediaInfoDto({
    required this.title,
    required this.formats,
    this.uploader,
    this.durationSec,
    this.thumbnailUrl,
    this.site,
    this.description,
    this.uploadDate,
  });

  String title;
  String? uploader;
  int? durationSec;
  String? thumbnailUrl;
  String? site;
  String? description;
  String? uploadDate;
  List<FormatDto> formats;
}

class DownloadRequestDto {
  DownloadRequestDto({
    required this.taskId,
    required this.url,
    required this.audioOnly,
    required this.autoSubs,
    required this.embedThumbnail,
    required this.embedMetadata,
    required this.outputDir,
    required this.filenameTemplate,
    required this.embedChapters,
    required this.splitChapters,
    this.formatId,
    this.container,
    this.subtitleLangs,
    this.subtitleFormat,
    this.rateLimit,
    this.concurrentFragments,
    this.audioQuality,
    this.downloadArchivePath,
    this.extraArgs,
    this.sponsorBlock,
    this.sponsorBlockCategories,
  });

  String taskId;
  String url;
  String? formatId;
  bool audioOnly;
  String? container;
  List<String>? subtitleLangs;
  bool autoSubs;
  String? subtitleFormat;
  bool embedThumbnail;
  bool embedMetadata;
  String outputDir;
  String filenameTemplate;
  String? rateLimit;
  int? concurrentFragments;
  String? audioQuality;
  String? downloadArchivePath;
  List<String>? extraArgs;
  String? sponsorBlock;
  List<String>? sponsorBlockCategories;
  bool embedChapters;
  bool splitChapters;
}

class ProgressDto {
  ProgressDto({
    required this.taskId,
    required this.percent,
    required this.speedBps,
    required this.stage,
    this.etaSec,
    this.error,
  });

  String taskId;
  double percent;
  double speedBps;
  int? etaSec;
  String stage; // probing | downloading | merging | done | error | canceled
  String? error;
}

@HostApi()
abstract class YtDlpHostApi {
  @async
  MediaInfoDto probe(String url);

  /// Raw `yt-dlp --flat-playlist -J <url>` stdout (parsed in Dart). Returns a
  /// single-video JSON when the URL isn't a playlist/carousel.
  @async
  String expandRaw(String url);

  void startDownload(DownloadRequestDto request);

  void cancel(String taskId);

  @async
  String engineVersions();

  @async
  void updateEngine();
}

@FlutterApi()
abstract class YtDlpFlutterApi {
  void onProgress(ProgressDto progress);
}

/// Foreground-service control + connectivity probe for the download queue.
@HostApi()
abstract class ServiceHostApi {
  void startService(String text, int progress, bool indeterminate);

  void updateNotification(String text, int progress, bool indeterminate);

  void stopService();

  @async
  bool isUnmetered();
}

@FlutterApi()
abstract class ServiceFlutterApi {
  /// The notification's "Stop" action was tapped.
  void onStopRequested();
}

/// Delivers text/URLs shared into the app via the Android share sheet
/// (`ACTION_SEND` / `ACTION_SEND_MULTIPLE`). See docs/design/P8-PLAN.md (P8a).
@HostApi()
abstract class ShareHostApi {
  /// The shared text the app was cold-launched with, consumed once (cleared on
  /// read). Null when the launch wasn't a share.
  String? takeInitialSharedText();
}

@FlutterApi()
abstract class ShareFlutterApi {
  /// A share arrived while the app was already running (`onNewIntent`).
  void onSharedText(String text);
}

/// Export a private library file to the device. [type] is video|audio|image.
@HostApi()
abstract class StorageHostApi {
  /// Launches the SAF folder picker; returns the persisted tree URI or null.
  @async
  String? pickExportFolder();

  /// Copies the file into a user-picked SAF tree; returns the saved doc URI.
  @async
  String exportToTree(
    String filePath,
    String treeUri,
    String type,
    String? subdir,
  );

  /// Copies the file into the public MediaStore (gallery-visible, API 29+).
  @async
  String exportToMediaStore(String filePath, String type, String? subdir);
}
