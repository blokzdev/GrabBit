import 'package:grabbit/core/ai/model_file.dart';

/// The on-device runtime that backs a [TranscriptionModel]. `transcriptionEngineFor`
/// (see `transcription_engine_factory.dart`) maps each value to a concrete
/// transcription engine. Whisper models are **file-based** (a single ggml `.bin`
/// the app downloads + SHA-256-verifies via `ModelDownloadService`, like the
/// onnx MiniLM embedder — *not* plugin-managed), so each carries a [ModelFile].
enum TranscriptionRuntime { whisperGgml }

/// The size/quality band of a [TranscriptionModel] — drives the picker badge so
/// a user can trade speed for accuracy knowingly (P12e). Larger = more accurate,
/// slower, bigger download + RAM.
enum TranscriptionModelClass { tiny, base, small, turbo }

/// An on-device speech-to-text model (P12e). All shipped models are the
/// **multilingual** ggml whisper conversions (MIT, ungated — HEAD-verified
/// unauthenticated downloads) to keep GrabBit's off-store posture clean
/// (CLAUDE.md §10). App-managed: [file] is fetched + SHA-256-verified + cached by
/// `ModelDownloadService`, and the cached path is handed to whisper.cpp as its
/// `modelPath` (P12e-2). Selection is tier-eligible + opt-in.
class TranscriptionModel {
  const TranscriptionModel({
    required this.id,
    required this.displayName,
    required this.file,
    required this.approxDownloadMb,
    required this.license,
    required this.modelClass,
    required this.blurb,
    this.runtime = TranscriptionRuntime.whisperGgml,
  });

  /// Stable identifier, persisted as the user's selection.
  final String id;

  /// Human-facing name shown in the picker.
  final String displayName;

  /// The single downloadable ggml asset (url + SHA-256 + size + filename),
  /// consumed by `ModelDownloadService` and resolved to a `modelPath` in P12e-2.
  final ModelFile file;

  /// Approximate download size in **decimal MB** (bytes ÷ 1e6, matching Android's
  /// file/download UI), surfaced in the picker. HEAD-verified against [file].
  final int approxDownloadMb;

  /// SPDX-ish license tag (all shipped whisper ggml models are MIT) — a posture guard.
  final String license;

  /// The size/quality band — drives the picker badge.
  final TranscriptionModelClass modelClass;

  /// One-line "smaller & faster" / "larger & better" style description.
  final String blurb;

  /// Which on-device runtime serves this model — the factory routes on it.
  final TranscriptionRuntime runtime;
}

/// **Tiny** — `ggml-tiny` (multilingual, MIT): the lightest rung; runs on any
/// tier, fastest, lowest accuracy. HEAD-verified ~78 MB.
const TranscriptionModel whisperTiny = TranscriptionModel(
  id: 'whisper-tiny',
  displayName: 'Whisper Tiny',
  file: ModelFile(
    url:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin',
    sha256: 'be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21',
    sizeBytes: 77691713,
    filename: 'ggml-tiny.bin',
  ),
  approxDownloadMb: 78,
  license: 'MIT',
  modelClass: TranscriptionModelClass.tiny,
  blurb: 'Smaller & faster — runs on any device.',
);

/// **Base (recommended)** — `ggml-base` (multilingual, MIT): the balanced default
/// on capable devices; a clear accuracy step over tiny. HEAD-verified ~148 MB.
const TranscriptionModel whisperBase = TranscriptionModel(
  id: 'whisper-base',
  displayName: 'Whisper Base',
  file: ModelFile(
    url:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
    sha256: '60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe',
    sizeBytes: 147951465,
    filename: 'ggml-base.bin',
  ),
  approxDownloadMb: 148,
  license: 'MIT',
  modelClass: TranscriptionModelClass.base,
  blurb: 'Recommended — best balance of accuracy and size.',
);

/// **Small** — `ggml-small` (multilingual, MIT): stronger accuracy, more RAM + a
/// bigger download. High-tier. HEAD-verified ~488 MB.
const TranscriptionModel whisperSmall = TranscriptionModel(
  id: 'whisper-small',
  displayName: 'Whisper Small',
  file: ModelFile(
    url:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin',
    sha256: '1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b',
    sizeBytes: 487601967,
    filename: 'ggml-small.bin',
  ),
  approxDownloadMb: 488,
  license: 'MIT',
  modelClass: TranscriptionModelClass.small,
  blurb: 'Larger & better — stronger accuracy, more RAM.',
);

/// **Flagship** — `ggml-large-v3-turbo` **q5_0** (multilingual, MIT): large-v3
/// quality at half a gigabyte (q5_0 quantization barely dents whisper accuracy,
/// so we ship it over the 1.6 GB f16 build). High-tier only. HEAD-verified ~574 MB.
const TranscriptionModel whisperLargeV3Turbo = TranscriptionModel(
  id: 'whisper-large-v3-turbo-q5_0',
  displayName: 'Whisper Large v3 Turbo',
  file: ModelFile(
    url:
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin',
    sha256: '394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2',
    sizeBytes: 574041195,
    filename: 'ggml-large-v3-turbo-q5_0.bin',
  ),
  approxDownloadMb: 574,
  license: 'MIT',
  modelClass: TranscriptionModelClass.turbo,
  blurb: 'Flagship — best accuracy; large download, needs lots of RAM.',
);

/// Every transcription model GrabBit knows about — the lookup set for a persisted
/// selection (P12e).
const List<TranscriptionModel> allTranscriptionModels = [
  whisperTiny,
  whisperBase,
  whisperSmall,
  whisperLargeV3Turbo,
];

/// Resolves a persisted transcription [id] to its catalog entry, or null if
/// unknown (e.g. a removed model) — callers fall back to the tier recommendation.
TranscriptionModel? transcriptionModelById(String id) {
  for (final m in allTranscriptionModels) {
    if (m.id == id) return m;
  }
  return null;
}
