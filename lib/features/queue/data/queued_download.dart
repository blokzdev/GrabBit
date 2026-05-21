import 'package:grabbit/core/engine/download_engine.dart';

/// What the queue persists in `download_tasks.requestJson`: the engine
/// [DownloadRequest] plus the probed display metadata needed to write the
/// library row when the download completes (the engine itself has no title).
class QueuedDownload {
  const QueuedDownload({
    required this.request,
    required this.title,
    this.site,
    this.durationSec,
    this.uploader,
    this.originalUrl,
    this.description,
    this.uploadDate,
    this.playlistId,
    this.playlistTitle,
  });

  factory QueuedDownload.fromJson(Map<String, dynamic> json) => QueuedDownload(
    request: DownloadRequest.fromJson(json['request'] as Map<String, dynamic>),
    title: json['title'] as String,
    site: json['site'] as String?,
    durationSec: json['durationSec'] as int?,
    uploader: json['uploader'] as String?,
    originalUrl: json['originalUrl'] as String?,
    description: json['description'] as String?,
    uploadDate: json['uploadDate'] as String?,
    playlistId: json['playlistId'] as String?,
    playlistTitle: json['playlistTitle'] as String?,
  );

  final DownloadRequest request;
  final String title;
  final String? site;
  final int? durationSec;
  final String? uploader;
  final String? originalUrl;
  final String? description;
  final String? uploadDate;
  final String? playlistId;
  final String? playlistTitle;

  Map<String, dynamic> toJson() => {
    'request': request.toJson(),
    'title': title,
    'site': site,
    'durationSec': durationSec,
    'uploader': uploader,
    'originalUrl': originalUrl,
    'description': description,
    'uploadDate': uploadDate,
    'playlistId': playlistId,
    'playlistTitle': playlistTitle,
  };
}
