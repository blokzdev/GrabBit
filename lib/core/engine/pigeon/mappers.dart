import 'package:grabbit/core/engine/download_engine.dart';
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
  );
}
