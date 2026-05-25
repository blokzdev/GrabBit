/// The pinned on-device embedder model. A minimal precursor to P11's full model
/// catalog — for P10b-2 we ship exactly one embedder, chosen for the smallest
/// download and **no gated-model auth** (no HuggingFace token).
///
/// **Gecko 64** (`litert-community/Gecko-110m-en`): 110M params, 768-d vectors,
/// 64-token max sequence, ~110 MB, ungated. The fastest of the family and ideal
/// for the short title/uploader/tag text we embed. EmbeddingGemma-300M is more
/// accurate but gated and larger — revisit if quality demands it.
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

  /// Output vector dimension (768 for the whole Gecko/EmbeddingGemma family).
  final int dimension;

  /// Approximate total download size in MB, surfaced in the opt-in copy.
  final int approxDownloadMb;
}

/// The single embedder GrabBit ships in v1.
const EmbedderModel geckoEmbedder = EmbedderModel(
  id: 'Gecko_64_quant',
  modelUrl:
      'https://huggingface.co/litert-community/Gecko-110m-en/resolve/main/Gecko_64_quant.tflite',
  tokenizerUrl:
      'https://huggingface.co/litert-community/Gecko-110m-en/resolve/main/sentencepiece.model',
  dimension: 768,
  approxDownloadMb: 110,
);
