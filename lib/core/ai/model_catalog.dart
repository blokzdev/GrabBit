/// The pinned on-device embedder model.
///
/// **P10g: EmbeddingGemma-300m** (`litert-community/embeddinggemma-300m`, seq256
/// export) — 768-d native, used at **256-d via Matryoshka** for a lean index;
/// **multilingual** (100+ languages, matching the captions P10f fetches) and a
/// 256-token window (vs Gecko's 64). The HF weights are **license-gated**, so we
/// **self-host** the `.tflite` + tokenizer (see `docs/AI-SPEC.md`) and download
/// them tokenlessly; the Gemma license + use-policy ship in-app.
///
/// `id`/`dimension` are persisted by P10b-2b so a model change re-keys the Cozo
/// HNSW relation + graph fingerprint (a new model → re-embed).
class EmbedderModel {
  const EmbedderModel({
    required this.id,
    required this.modelUrl,
    required this.tokenizerUrl,
    required this.dimension,
    required this.approxDownloadMb,
  });

  /// Stable identifier (the model filename without extension). Persisted so a
  /// later model swap invalidates cached embeddings.
  final String id;

  /// HTTPS URL of the `.tflite` LiteRT embedder weights.
  final String modelUrl;

  /// HTTPS URL of the SentencePiece tokenizer (same `.model` on every platform).
  final String tokenizerUrl;

  /// Output vector dimension actually stored/indexed. EmbeddingGemma emits 768;
  /// we keep the first [dimension] dims (Matryoshka) — see `flutter_gemma_inference_engine.dart`.
  final int dimension;

  /// Approximate total download size in MB, surfaced in the opt-in copy.
  final int approxDownloadMb;
}

/// The single embedder GrabBit ships in v1 (P10g).
///
/// TODO(P10g): point [modelUrl]/[tokenizerUrl] at the public GrabBit-hosted
/// release assets once uploaded (EmbeddingGemma is HF-gated; we self-host).
/// Source files: `embeddinggemma-300M_seq256_mixed-precision.tflite` (179 MB) +
/// `sentencepiece.model` (4.68 MB) from `litert-community/embeddinggemma-300m`.
const EmbedderModel embeddingGemmaEmbedder = EmbedderModel(
  id: 'embeddinggemma_300m_seq256',
  modelUrl:
      'https://github.com/blokzdev/grabbit-models/releases/download/v1/embeddinggemma-300M_seq256_mixed-precision.tflite',
  tokenizerUrl:
      'https://github.com/blokzdev/grabbit-models/releases/download/v1/sentencepiece.model',
  dimension: 256,
  approxDownloadMb: 184,
);
