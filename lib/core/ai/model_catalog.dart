/// The on-device runtime that backs an [EmbedderModel]. `inferenceEngineFor`
/// (see `inference_engine_factory.dart`) maps each value to a concrete
/// [InferenceEngine]. P10g-3 adds `onnx` for the multilingual MiniLM engine.
enum EmbedderRuntime { flutterGemma }

/// The pinned on-device embedder model. A minimal precursor to P12's full model
/// catalog — for P10 we ship exactly one embedder, chosen for an Apache-2.0,
/// ungated download (no HuggingFace token).
///
/// **Gecko 256** (`litert-community/Gecko-110m-en` → `Gecko_256_quant.tflite`):
/// 110M params, 768-d vectors, **256-token** max sequence, ~114 MB, Apache-2.0,
/// ungated. P10g-1 moved up from the seq64 export so the embed doc can include a
/// real slice of the **transcript** (see `embedding_doc.dart`). The seq512/1024
/// variants share this tokenizer + dimension; the pluggable engine seam lands in
/// P10g-2, and the capability-selected window upgrade is owned by the P12
/// device-tier system. Multilingual is added via a second engine in P10g-3.
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
    this.runtime = EmbedderRuntime.flutterGemma,
  });

  /// Stable identifier (the model filename without extension). Persisted so a
  /// later model swap invalidates cached embeddings.
  final String id;

  /// HTTPS URL of the `.tflite` LiteRT embedder weights.
  final String modelUrl;

  /// HTTPS URL of the SentencePiece tokenizer (same `.model` on every platform).
  final String tokenizerUrl;

  /// Output vector dimension (768 across the Gecko seq variants).
  final int dimension;

  /// Approximate total download size in MB, surfaced in the opt-in copy.
  final int approxDownloadMb;

  /// Which on-device runtime serves this model — the factory routes on it.
  final EmbedderRuntime runtime;
}

/// The single embedder GrabBit ships in v1.
const EmbedderModel geckoEmbedder = EmbedderModel(
  id: 'Gecko_256_quant',
  modelUrl:
      'https://huggingface.co/litert-community/Gecko-110m-en/resolve/main/Gecko_256_quant.tflite',
  tokenizerUrl:
      'https://huggingface.co/litert-community/Gecko-110m-en/resolve/main/sentencepiece.model',
  dimension: 768,
  approxDownloadMb: 114,
);

/// The embedder selected by default. `activeEmbedderModelProvider` returns this
/// today; P12's device-capability/tier system is the override point.
const EmbedderModel defaultEmbedder = geckoEmbedder;
