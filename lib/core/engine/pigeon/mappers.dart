import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/download_error.dart';
import 'package:grabbit/core/engine/error_mapping.dart';
import 'package:grabbit/core/engine/pigeon/engine.pigeon.dart';

/// Conversions between the Pigeon transport DTOs and the pure-Dart domain
/// models. Kept separate so they can be unit-tested without a platform channel.
extension FormatDtoMapper on FormatDto {
  MediaFormat toDomain() => MediaFormat(
    id: id,
    ext: ext,
    label: label,
    audioOnly: audioOnly,
    height: height,
    tbr: tbr,
    vcodec: vcodec,
    acodec: acodec,
    filesize: filesize,
  );
}

extension MediaInfoDtoMapper on MediaInfoDto {
  MediaInfo toDomain() => MediaInfo(
    title: title,
    formats: formats.map((f) => f.toDomain()).toList(),
    uploader: uploader,
    durationSec: durationSec,
    thumbnailUrl: thumbnailUrl,
    site: site,
    description: description,
    uploadDate: uploadDate,
  );
}

extension DownloadRequestMapper on DownloadRequest {
  DownloadRequestDto toDto() => DownloadRequestDto(
    taskId: taskId,
    url: url,
    formatId: formatId,
    audioOnly: audioOnly,
    container: container,
    subtitles: subtitles,
    embedThumbnail: embedThumbnail,
    embedMetadata: embedMetadata,
    outputDir: outputDir,
    filenameTemplate: filenameTemplate,
  );
}

DownloadStage _stageFromString(String stage) => switch (stage) {
  'probing' => DownloadStage.probing,
  'downloading' => DownloadStage.downloading,
  'merging' => DownloadStage.merging,
  'done' => DownloadStage.done,
  'canceled' => DownloadStage.canceled,
  _ => DownloadStage.error,
};

extension ProgressDtoMapper on ProgressDto {
  DownloadProgress toDomain() {
    final mappedStage = _stageFromString(stage);
    return DownloadProgress(
      taskId: taskId,
      stage: mappedStage,
      percent: percent,
      speedBps: speedBps,
      etaSec: etaSec,
      errorCode: switch (mappedStage) {
        DownloadStage.error => classifyEngineError(error),
        DownloadStage.canceled => DownloadErrorCode.canceled,
        _ => null,
      },
    );
  }
}
