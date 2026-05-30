import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:grabbit/core/ai/inference_engine.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/ai/model_download_service.dart';
import 'package:grabbit/core/ai/multilingual_tokenizer.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

/// On-device multilingual embedder (P12c-2): runs `paraphrase-multilingual-
/// MiniLM-L12-v2` on **onnxruntime**. Mirrors `FlutterGemmaInferenceEngine`'s
/// lazy-load + error shape. The model + tokenizer are app-managed (downloaded +
/// SHA-256-verified by [ModelDownloadService]); the XLM-R tokenizer is the
/// pure-Dart [MultilingualEmbedderTokenizer] (P12c-1). Embeddings are the
/// mean-pooled (attention-masked) `last_hidden_state`, **L2-normalized** (the
/// Cozo HNSW metric is cosine).
class OnnxEmbedderInferenceEngine implements InferenceEngine {
  OnnxEmbedderInferenceEngine(this._model, this._downloads);

  final EmbedderModel _model;
  final ModelDownloadService _downloads;

  OrtSession? _session;
  MultilingualEmbedderTokenizer? _tokenizer;

  @override
  EmbedderModel get model => _model;

  @override
  int get dimension => _model.dimension;

  @override
  bool get isAvailable => _session != null && _tokenizer != null;

  @override
  Future<void> downloadModel({void Function(double progress)? onProgress}) =>
      _downloads.ensureDownloaded(
        _model.id,
        _model.files,
        onProgress: onProgress,
      );

  @override
  Future<bool> ensureReady() async {
    if (isAvailable) return true;
    try {
      if (!await _downloads.isInstalled(_model.id, _model.files)) return false;
      final tokenizerPath = await _downloads.pathFor(
        _model.id,
        'tokenizer.json',
      );
      final modelPath = await _downloads.pathFor(_model.id, 'model.onnx');
      final tokenizer = MultilingualEmbedderTokenizer.fromJson(
        await File(tokenizerPath).readAsString(),
      );
      OrtEnv.instance.init();
      final session = OrtSession.fromFile(File(modelPath), OrtSessionOptions());
      _tokenizer = tokenizer;
      _session = session;
      return true;
    } catch (e) {
      _session = null;
      _tokenizer = null;
      throw InferenceException(
        InferenceErrorCode.loadFailed,
        'Failed to load the multilingual embedder',
        cause: e,
      );
    }
  }

  @override
  Future<List<double>> embed(String text) async {
    final result = await embedBatch([text]);
    return result.first;
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async {
    final session = _session;
    final tokenizer = _tokenizer;
    if (session == null || tokenizer == null) {
      throw const InferenceException(
        InferenceErrorCode.unavailable,
        'The multilingual embedder is not loaded',
      );
    }
    if (texts.isEmpty) return const [];
    try {
      final rows = tokenizer.encodeBatch(texts, maxTokens: _model.maxTokens);
      final batch = rows.length;
      final seq = rows.first.inputIds.length;

      // Static type List<int> satisfies the tensor API; the runtime Int64List
      // makes onnxruntime build an int64 tensor (what the BERT graph expects).
      final List<int> inputIds = Int64List(batch * seq);
      final List<int> attention = Int64List(batch * seq);
      // XLM-R doesn't use segment ids, but the BERT-arch graph requires the
      // input — feed zeros.
      final List<int> tokenType = Int64List(batch * seq);
      for (var b = 0; b < batch; b++) {
        for (var i = 0; i < seq; i++) {
          inputIds[b * seq + i] = rows[b].inputIds[i];
          attention[b * seq + i] = rows[b].attentionMask[i];
        }
      }
      final shape = [batch, seq];
      final inputs = <String, OrtValueTensor>{
        'input_ids': OrtValueTensor.createTensorWithDataList(inputIds, shape),
        'attention_mask': OrtValueTensor.createTensorWithDataList(
          attention,
          shape,
        ),
        'token_type_ids': OrtValueTensor.createTensorWithDataList(
          tokenType,
          shape,
        ),
      };
      // Only feed the inputs the model actually declares.
      inputs.removeWhere((name, _) => !session.inputNames.contains(name));

      final runOptions = OrtRunOptions();
      List<OrtValue?>? outputs;
      try {
        outputs = session.run(runOptions, inputs);
        final hidden = outputs.first!.value as List; // [batch][seq][dim]
        return [
          for (var b = 0; b < batch; b++)
            l2Normalize(
              meanPool(_toRows(hidden[b] as List), rows[b].attentionMask),
            ),
        ];
      } finally {
        for (final tensor in inputs.values) {
          tensor.release();
        }
        runOptions.release();
        outputs?.forEach((o) => o?.release());
      }
    } on InferenceException {
      rethrow;
    } catch (e) {
      throw InferenceException(
        InferenceErrorCode.embedFailed,
        'Failed to embed text with the multilingual embedder',
        cause: e,
      );
    }
  }

  @override
  Future<void> close() async {
    await _session?.release();
    _session = null;
    _tokenizer = null;
  }

  List<List<double>> _toRows(List<dynamic> seqRows) => [
    for (final row in seqRows) (row as List).cast<double>(),
  ];
}

/// Mean-pools `last_hidden_state` token rows over the positions where
/// [attentionMask] is 1 (padding ignored). Returns a vector of the model
/// dimension. An all-pad input yields a zero vector.
List<double> meanPool(List<List<double>> tokenRows, List<int> attentionMask) {
  final dim = tokenRows.isEmpty ? 0 : tokenRows.first.length;
  final pooled = List<double>.filled(dim, 0);
  var count = 0;
  for (var i = 0; i < tokenRows.length; i++) {
    if (i >= attentionMask.length || attentionMask[i] == 0) continue;
    final row = tokenRows[i];
    for (var j = 0; j < dim; j++) {
      pooled[j] += row[j];
    }
    count++;
  }
  if (count > 0) {
    for (var j = 0; j < dim; j++) {
      pooled[j] /= count;
    }
  }
  return pooled;
}

/// L2-normalizes [v] to unit length (so a dot product equals cosine similarity).
/// A zero vector is returned unchanged.
List<double> l2Normalize(List<double> v) {
  var sum = 0.0;
  for (final x in v) {
    sum += x * x;
  }
  final norm = math.sqrt(sum);
  if (norm == 0) return v;
  return [for (final x in v) x / norm];
}
