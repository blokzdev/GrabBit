/// Typed download failure taxonomy (see docs/SPEC.md §6).
enum DownloadErrorCode {
  network,
  unsupportedSite,
  extractorFailed,
  formatUnavailable,
  ffmpegFailed,
  storageFull,
  permissionDenied,
  canceled,
  unknown,
}

extension DownloadErrorCodeX on DownloadErrorCode {
  /// Transient codes are eligible for retry with backoff; the rest are terminal.
  bool get isRetryable => switch (this) {
    DownloadErrorCode.network || DownloadErrorCode.extractorFailed => true,
    _ => false,
  };
}

class DownloadException implements Exception {
  const DownloadException(this.code, this.message, {this.cause});

  final DownloadErrorCode code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'DownloadException($code): $message';
}
