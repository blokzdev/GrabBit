import 'package:grabbit/core/engine/download_error.dart';

/// Classifies a raw yt-dlp/engine failure message into the typed taxonomy.
/// Pure and case-insensitive so it can be unit-tested without a device.
DownloadErrorCode classifyEngineError(String? message) {
  final m = (message ?? '').toLowerCase();
  if (m.isEmpty) return DownloadErrorCode.unknown;
  if (m.contains('unsupported url') || m.contains('is not a valid url')) {
    return DownloadErrorCode.unsupportedSite;
  }
  if (m.contains('requested format') || m.contains('format is not available')) {
    return DownloadErrorCode.formatUnavailable;
  }
  if (m.contains('ffmpeg')) return DownloadErrorCode.ffmpegFailed;
  if (m.contains('permission')) return DownloadErrorCode.permissionDenied;
  if (m.contains('no space') || m.contains('not enough storage')) {
    return DownloadErrorCode.storageFull;
  }
  if (m.contains('timed out') ||
      m.contains('connection') ||
      m.contains('network') ||
      m.contains('unable to download webpage')) {
    return DownloadErrorCode.network;
  }
  if (m.contains('unable to extract') || m.contains('extractor')) {
    return DownloadErrorCode.extractorFailed;
  }
  return DownloadErrorCode.unknown;
}
