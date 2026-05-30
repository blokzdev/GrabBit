/// One downloadable asset of a **file-based** on-device model (P12b): a single
/// HTTPS file that `ModelDownloadService` fetches, SHA-256-verifies, and caches
/// under app-private storage. File-based runtimes (onnxruntime, whisper) own
/// their files this way; the flutter_gemma embedder does **not** — the plugin
/// fetches and manages its files opaquely (see `flutter_gemma_embedder_engine.dart`),
/// so its `EmbedderModel.files` stays empty.
class ModelFile {
  const ModelFile({
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    required this.filename,
  });

  /// HTTPS source URL.
  final String url;

  /// Lowercase-hex SHA-256 of the file's bytes, verified after download. A
  /// mismatch is rejected with `InferenceErrorCode.downloadFailed`.
  final String sha256;

  /// Exact size in bytes — drives the pre-download free-space guard and the
  /// progress denominator when the server omits `Content-Length`.
  final int sizeBytes;

  /// On-disk name under `<appSupport>/models/<modelId>/<filename>`.
  final String filename;
}
