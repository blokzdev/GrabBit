import 'package:grabbit/core/ai/model_file.dart';

/// The on-device runtime that backs an [EmbedderModel]. `inferenceEngineFor`
/// (see `inference_engine_factory.dart`) maps each value to a concrete
/// [InferenceEngine].
enum EmbedderRuntime {
  /// MediaPipe / LiteRT via the flutter_gemma plugin (Gecko). The plugin fetches
  /// and manages its files opaquely, so these entries carry no [EmbedderModel.files].
  flutterGemma,

  /// onnxruntime — the multilingual MiniLM engine (P12c). App-managed download
  /// via `ModelDownloadService`; entries carry SHA-256'd [EmbedderModel.files].
  onnx,
}

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
/// device-tier system. Multilingual is added via a second engine in P12.
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
    this.maxTokens = 256,
    this.runtime = EmbedderRuntime.flutterGemma,
    this.files = const [],
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

  /// Max input sequence length (the model window). The onnx engine truncates the
  /// embed doc to this; the flutter_gemma engine handles its own window (256).
  final int maxTokens;

  /// Which on-device runtime serves this model — the factory routes on it.
  final EmbedderRuntime runtime;

  /// App-managed downloadable assets (model + tokenizer), each with a SHA-256,
  /// for file-based runtimes ([EmbedderRuntime.onnx]). **Empty for
  /// [EmbedderRuntime.flutterGemma]**, whose files the plugin fetches and
  /// verifies opaquely. `ModelDownloadService` consumes this list.
  final List<ModelFile> files;
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

/// The multilingual embedder (P12c): `paraphrase-multilingual-MiniLM-L12-v2`
/// (Apache-2.0, ungated, 50 languages, 384-d, 128-token window) on onnxruntime.
/// `model.onnx` is the int8-quantized export (~118 MB); `tokenizer.json` is the
/// XLM-R tokenizer (same file P12c-1's fidelity gate was generated from). Both
/// are app-managed (SHA-256-verified) via `ModelDownloadService`. **Not yet in
/// the capability matrix** — P12c-2 only exposes it behind a self-test; P12c-3
/// makes it selectable. Gecko stays the universal fallback.
const EmbedderModel paraphraseMultilingualMiniLmL12V2 = EmbedderModel(
  id: 'paraphrase-multilingual-MiniLM-L12-v2',
  modelUrl:
      'https://huggingface.co/Xenova/paraphrase-multilingual-MiniLM-L12-v2/resolve/main/onnx/model_quantized.onnx',
  tokenizerUrl:
      'https://huggingface.co/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2/resolve/main/tokenizer.json',
  dimension: 384,
  approxDownloadMb: 121,
  maxTokens: 128,
  runtime: EmbedderRuntime.onnx,
  files: [
    ModelFile(
      url:
          'https://huggingface.co/Xenova/paraphrase-multilingual-MiniLM-L12-v2/resolve/main/onnx/model_quantized.onnx',
      sha256:
          '66fc00f5f29afcaff34092e1bdd20008ca3918265a82fb9695a551e510cc4ebc',
      sizeBytes: 118308126,
      filename: 'model.onnx',
    ),
    ModelFile(
      url:
          'https://huggingface.co/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2/resolve/main/tokenizer.json',
      sha256:
          '2c3387be76557bd40970cec13153b3bbf80407865484b209e655e5e4729076b8',
      sizeBytes: 9081518,
      filename: 'tokenizer.json',
    ),
  ],
);
