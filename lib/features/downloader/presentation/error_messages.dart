import 'package:grabbit/core/engine/download_error.dart';

/// Maps an engine error code to friendly, actionable copy (falls back to the
/// raw message when there's nothing better to say).
String friendlyError(DownloadErrorCode? code, String fallback) =>
    switch (code) {
      DownloadErrorCode.unsupportedSite =>
        "This link isn't supported. The site may be unsupported here, or the "
            'downloader engine may be out of date.',
      DownloadErrorCode.extractorFailed =>
        "Couldn't read this link. The site likely changed — updating the "
            'downloader engine often fixes this.',
      DownloadErrorCode.network =>
        'Network problem. Check your connection and try again.',
      DownloadErrorCode.formatUnavailable =>
        "The requested quality isn't available for this link.",
      DownloadErrorCode.storageFull => 'Not enough storage to download this.',
      DownloadErrorCode.permissionDenied => 'Permission denied while saving.',
      _ => fallback,
    };

/// Whether the error is the kind a yt-dlp self-update commonly fixes.
bool suggestsEngineUpdate(DownloadErrorCode? code) =>
    code == DownloadErrorCode.unsupportedSite ||
    code == DownloadErrorCode.extractorFailed;
