import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/download_error.dart';
import 'package:grabbit/core/engine/error_mapping.dart';
import 'package:grabbit/core/engine/pigeon/engine.pigeon.dart';
import 'package:grabbit/core/engine/progress_line.dart';

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
    id: id,
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
    subtitleLangs: subtitleLangs,
    autoSubs: autoSubs,
    subtitleFormat: subtitleFormat,
    embedThumbnail: embedThumbnail,
    embedMetadata: embedMetadata,
    outputDir: outputDir,
    filenameTemplate: filenameTemplate,
    rateLimit: rateLimit,
    concurrentFragments: concurrentFragments,
    audioQuality: audioQuality,
    downloadArchivePath: downloadArchivePath,
    extraArgs: extraArgs,
    sponsorBlock: sponsorBlock,
    sponsorBlockCategories: sponsorBlockCategories,
    embedChapters: embedChapters,
    splitChapters: splitChapters,
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
    // The native callback drops speed/total size; recover them from the raw line.
    final parsed = parseProgressLine(line);
    return DownloadProgress(
      taskId: taskId,
      stage: mappedStage,
      percent: percent,
      speedBps: parsed.speedBps ?? speedBps,
      etaSec: etaSec,
      totalBytes: parsed.totalBytes,
      errorCode: switch (mappedStage) {
        DownloadStage.error => classifyEngineError(error),
        DownloadStage.canceled => DownloadErrorCode.canceled,
        _ => null,
      },
    );
  }
}
