import 'package:grabbit/core/ai/model_catalog.dart';

/// Platform-agnostic on-device inference engine. P10b-2a exposes only the
/// **embedding** slice that powers semantic search / similarity; generation and
/// transcription arrive with the LLM runtime in P11. Backed by `flutter_gemma`
/// (embedder-only) on Android; a graceful no-op stub elsewhere and until the
/// user opts in. UI and feature code depend only on this interface, never a
/// concrete runtime (mirrors `GraphStore` / `DownloadEngine`).
///
/// Embeddings are an enhancement: the graph's metadata features work without
/// them, so every method degrades gracefully — [isAvailable] gates use, and
/// [embed] throws [InferenceErrorCode.unavailable] only when called while the
/// model isn't ready.
abstract interface class InferenceEngine {
  /// The pinned embedder model (id, download URLs, dimension) this engine uses.
  EmbedderModel get model;

  /// Whether the model is downloaded, loaded, and ready to [embed]. False on
  /// unsupported platforms, before opt-in, or after a load failure.
  bool get isAvailable;

  /// The embedding vector dimension (see [EmbedderModel.dimension]). Stable for
  /// a given model, so P10b-2b can size the Cozo HNSW relation from it.
  int get dimension;

  /// Downloads the model + tokenizer (the only AI-related network call), opt-in.
  /// [onProgress] reports 0.0–1.0 across both files. Idempotent: a no-op when
  /// already installed. Throws [InferenceErrorCode.downloadFailed] on failure.
  Future<void> downloadModel({void Function(double progress)? onProgress});

  /// Ensures the model is downloaded and loaded, returning whether the engine is
  /// now [isAvailable]. Does **not** trigger a download — call [downloadModel]
  /// first (gated behind the user's opt-in).
  Future<bool> ensureReady();

  /// Embeds [text] into a [dimension]-length vector. Throws
  /// [InferenceErrorCode.unavailable] when the engine isn't ready.
  Future<List<double>> embed(String text);

  /// Embeds [texts] in one native round-trip, returning a vector per input (in
  /// order). Used by the embedding backfill to cut per-item overhead. Throws
  /// [InferenceErrorCode.unavailable] when the engine isn't ready.
  Future<List<List<double>>> embedBatch(List<String> texts);

  /// Releases native resources held by the loaded model.
  Future<void> close();
}
