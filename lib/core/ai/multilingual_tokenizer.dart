import 'dart:convert';
import 'dart:typed_data';

import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Token ids + attention mask for one input (or one row of a padded batch),
/// ready to feed an onnx embedder session (P12c).
typedef TokenizedInput = ({Int32List inputIds, Int32List attentionMask});

/// The multilingual embedder's tokenizer (P12c): a hand-rolled, pure-Dart
/// implementation of the **XLM-RoBERTa SentencePiece (Unigram)** tokenizer used
/// by `paraphrase-multilingual-MiniLM-L12-v2`, loaded from the model's
/// HuggingFace `tokenizer.json`.
///
/// It reproduces HuggingFace token ids **exactly** (fidelity-tested against
/// golden vectors), running fully on-device. The pipeline mirrors XLM-R:
/// 1. **NFKC** normalization (XLM-R's `Precompiled` charsmap normalizer is
///    NFKC-equivalent — verified against the reference tokenizer);
/// 2. **whitespace split + metaspace** — split on whitespace, prefix each word
///    with `▁` (U+2581);
/// 3. **Unigram Viterbi** — the max-score segmentation over the model vocab,
///    with out-of-vocabulary runs collapsing to a single `<unk>`;
/// 4. wrap in `<s>` … `</s>` and truncate to the model window.
///
/// No live consumer yet — the onnx engine wires it in P12c-2.
class MultilingualEmbedderTokenizer {
  MultilingualEmbedderTokenizer._(
    this._vocab,
    this._maxPieceRunes, {
    required this.bosId,
    required this.eosId,
    required this.padId,
    required this.unkId,
  });

  /// `▁` — the SentencePiece whitespace marker.
  static const String _metaspace = '▁';

  /// Score for an out-of-vocabulary single character; far below any real piece
  /// score, so a real-piece path always wins and `<unk>` is only ever chosen
  /// when a character has no vocabulary coverage at all.
  static const double _unkScore = -1e9;

  final Map<String, _Piece> _vocab;
  final int _maxPieceRunes;
  final int bosId;
  final int eosId;
  final int padId;
  final int unkId;

  /// Builds the tokenizer from a HuggingFace `tokenizer.json` string.
  factory MultilingualEmbedderTokenizer.fromJson(String tokenizerJson) {
    final data = jsonDecode(tokenizerJson) as Map<String, dynamic>;
    final model = data['model'] as Map<String, dynamic>;
    final rawVocab = model['vocab'] as List<dynamic>;

    final vocab = <String, _Piece>{};
    var maxRunes = 1;
    for (var i = 0; i < rawVocab.length; i++) {
      final entry = rawVocab[i] as List<dynamic>;
      final piece = entry[0] as String;
      vocab[piece] = _Piece(i, (entry[1] as num).toDouble());
      final runes = piece.runes.length;
      if (runes > maxRunes) maxRunes = runes;
    }

    int idOf(String piece, int fallback) => vocab[piece]?.id ?? fallback;
    return MultilingualEmbedderTokenizer._(
      vocab,
      maxRunes,
      bosId: idOf('<s>', 0),
      eosId: idOf('</s>', 2),
      padId: idOf('<pad>', 1),
      unkId: (model['unk_id'] as num?)?.toInt() ?? idOf('<unk>', 3),
    );
  }

  /// Encodes [text] into ids + attention mask, truncated to [maxTokens] total
  /// (the two specials included), matching HuggingFace.
  TokenizedInput encode(String text, {required int maxTokens}) {
    final ids = _encode(text, maxTokens);
    return (
      inputIds: Int32List.fromList(ids),
      attentionMask: Int32List(ids.length)..fillRange(0, ids.length, 1),
    );
  }

  /// Encodes a batch, right-padded (`<pad>`) to the batch's longest row (each
  /// truncated to [maxTokens]) with attention masks — one batched onnx
  /// round-trip for the embedding backfill.
  List<TokenizedInput> encodeBatch(
    List<String> texts, {
    required int maxTokens,
  }) {
    if (texts.isEmpty) return const [];
    final rows = [for (final t in texts) _encode(t, maxTokens)];
    final width = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    return [
      for (final row in rows)
        () {
          final ids = Int32List(width);
          final mask = Int32List(width);
          for (var i = 0; i < row.length; i++) {
            ids[i] = row[i];
            mask[i] = 1;
          }
          for (var i = row.length; i < width; i++) {
            ids[i] = padId;
          }
          return (inputIds: ids, attentionMask: mask);
        }(),
    ];
  }

  /// The full id sequence (`<s>` … `</s>`), truncated to [maxTokens] total.
  List<int> _encode(String text, int maxTokens) {
    final pieces = <int>[];
    for (final word in unorm.nfkc(text).split(RegExp(r'\s+'))) {
      if (word.isNotEmpty) _viterbi('$_metaspace$word', pieces);
    }
    // Collapse consecutive <unk> into one (SentencePiece behaviour).
    final content = <int>[];
    for (final id in pieces) {
      if (id == unkId && content.isNotEmpty && content.last == unkId) continue;
      content.add(id);
    }
    final keep = maxTokens - 2;
    final body = content.length > keep ? content.sublist(0, keep) : content;
    return [bosId, ...body, eosId];
  }

  /// Appends the best (max-score) Unigram segmentation of [token] to [out].
  void _viterbi(String token, List<int> out) {
    final runes = token.runes.toList(growable: false);
    final n = runes.length;
    final best = List<double>.filled(n + 1, double.negativeInfinity);
    final fromPos = List<int>.filled(n + 1, -1);
    final pieceId = List<int>.filled(n + 1, -1);
    best[0] = 0;

    for (var i = 0; i < n; i++) {
      if (best[i] == double.negativeInfinity) continue;
      final maxLen = (n - i) < _maxPieceRunes ? (n - i) : _maxPieceRunes;
      final buffer = StringBuffer();
      var matchedSingleChar = false;
      for (var len = 1; len <= maxLen; len++) {
        buffer.writeCharCode(runes[i + len - 1]);
        final piece = _vocab[buffer.toString()];
        if (piece == null) continue;
        if (len == 1) matchedSingleChar = true;
        final score = best[i] + piece.score;
        if (score > best[i + len]) {
          best[i + len] = score;
          fromPos[i + len] = i;
          pieceId[i + len] = piece.id;
        }
      }
      // A char with no single-char piece falls back to <unk> so the path stays
      // reachable; adjacent <unk>s are merged by the caller.
      if (!matchedSingleChar) {
        final score = best[i] + _unkScore;
        if (score > best[i + 1]) {
          best[i + 1] = score;
          fromPos[i + 1] = i;
          pieceId[i + 1] = unkId;
        }
      }
    }

    final reversed = <int>[];
    for (var pos = n; pos > 0; pos = fromPos[pos]) {
      reversed.add(pieceId[pos]);
    }
    out.addAll(reversed.reversed);
  }
}

class _Piece {
  const _Piece(this.id, this.score);
  final int id;
  final double score;
}
