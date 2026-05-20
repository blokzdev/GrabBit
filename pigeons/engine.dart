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
  });

  String title;
  String? uploader;
  int? durationSec;
  String? thumbnailUrl;
  String? site;
  List<FormatDto> formats;
}

class DownloadRequestDto {
  DownloadRequestDto({
    required this.taskId,
    required this.url,
    required this.audioOnly,
    required this.subtitles,
    required this.embedThumbnail,
    required this.embedMetadata,
    required this.outputDir,
    required this.filenameTemplate,
    this.formatId,
    this.container,
  });

  String taskId;
  String url;
  String? formatId;
  bool audioOnly;
  String? container;
  bool subtitles;
  bool embedThumbnail;
  bool embedMetadata;
  String outputDir;
  String filenameTemplate;
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
