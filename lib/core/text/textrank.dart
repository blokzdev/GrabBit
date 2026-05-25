/// Pure extractive summarizer (P10e). Zero-dependency TextRank: no Flutter,
/// engine, or AI imports — runs on any device, synchronously, offline. Feeds
/// the item-detail "Summary" TL;DR. Unit-testable in isolation.
library;

import 'dart:math' as math;

/// Condenses [text] into its most central sentences (a TL;DR), returned
/// **verbatim in original document order**.
///
/// Returns `const []` when there is nothing worth condensing — input with at
/// most [minSentences] sentences (already its own TL;DR) or no usable content
/// tokens. Deterministic for a given input. Never throws.
List<String> summarize(
  String text, {
  int maxSentences = 3,
  int minSentences = 4,
}) {
  final sentences = _splitSentences(text);
  if (sentences.length <= minSentences) return const [];

  final tokens = [for (final s in sentences) _tokenize(s)];
  // Sentences with no content tokens can't relate to anything; if every
  // sentence is empty there's nothing to rank.
  if (tokens.every((t) => t.isEmpty)) return const [];

  final scores = _pageRank(_similarityMatrix(tokens));

  final order = [for (var i = 0; i < sentences.length; i++) i]
    ..sort((a, b) {
      final byScore = scores[b].compareTo(scores[a]);
      return byScore != 0 ? byScore : a.compareTo(b);
    });

  final chosen =
      (order.length > maxSentences ? order.sublist(0, maxSentences) : order)
        ..sort();
  return [for (final i in chosen) sentences[i]];
}

/// Splits prose into trimmed sentences, dropping empty/too-short fragments and
/// URL-only lines (common boilerplate in video descriptions).
List<String> _splitSentences(String text) {
  final out = <String>[];
  for (final raw in text.split(_sentenceBoundary)) {
    final s = raw.trim();
    if (s.length < 16) continue; // skip fragments / labels
    if (_urlOnly.hasMatch(s)) continue;
    out.add(s);
  }
  return out;
}

/// Lowercased content tokens: alphanumeric runs of length >= 2 with stopwords
/// removed. Returns a set (TextRank similarity counts distinct shared tokens).
Set<String> _tokenize(String sentence) {
  final out = <String>{};
  for (final m in _word.allMatches(sentence.toLowerCase())) {
    final w = m[0]!;
    if (w.length < 2 || _stopwords.contains(w)) continue;
    out.add(w);
  }
  return out;
}

/// Classic TextRank sentence similarity: shared-token count normalized by the
/// sum of the log lengths. `0` when either sentence has <= 1 content token or
/// the pair shares nothing.
List<List<double>> _similarityMatrix(List<Set<String>> tokens) {
  final n = tokens.length;
  final m = [for (var i = 0; i < n; i++) List<double>.filled(n, 0)];
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      final ti = tokens[i];
      final tj = tokens[j];
      if (ti.length < 2 || tj.length < 2) continue;
      var shared = 0;
      for (final w in ti) {
        if (tj.contains(w)) shared++;
      }
      if (shared == 0) continue;
      final norm = math.log(ti.length) + math.log(tj.length);
      if (norm <= 0) continue;
      final w = shared / norm;
      m[i][j] = w;
      m[j][i] = w;
    }
  }
  return m;
}

/// Weighted PageRank via power iteration. Deterministic: uniform init, fixed
/// damping, capped iterations with epsilon convergence.
List<double> _pageRank(
  List<List<double>> weights, {
  double damping = 0.85,
  int maxIterations = 30,
  double epsilon = 1e-6,
}) {
  final n = weights.length;
  if (n == 0) return const [];
  final outSum = [
    for (var i = 0; i < n; i++) weights[i].fold<double>(0, (a, b) => a + b),
  ];
  var scores = List<double>.filled(n, 1.0);
  final base = (1 - damping);

  for (var iter = 0; iter < maxIterations; iter++) {
    final next = List<double>.filled(n, base);
    for (var i = 0; i < n; i++) {
      var sum = 0.0;
      for (var j = 0; j < n; j++) {
        if (i == j || weights[j][i] == 0 || outSum[j] == 0) continue;
        sum += weights[j][i] / outSum[j] * scores[j];
      }
      next[i] = base + damping * sum;
    }
    var delta = 0.0;
    for (var i = 0; i < n; i++) {
      delta += (next[i] - scores[i]).abs();
    }
    scores = next;
    if (delta < epsilon) break;
  }
  return scores;
}

final _sentenceBoundary = RegExp(r'(?<=[.!?])\s+|[\r\n]+');
final _urlOnly = RegExp(r'^\s*https?://\S+\s*$', caseSensitive: false);
final _word = RegExp(r'[a-z0-9]+');

/// Small inline English stopword list (zero-dependency).
const _stopwords = <String>{
  'the',
  'and',
  'for',
  'are',
  'but',
  'not',
  'you',
  'all',
  'any',
  'can',
  'her',
  'was',
  'one',
  'our',
  'out',
  'his',
  'has',
  'had',
  'how',
  'its',
  'who',
  'did',
  'yes',
  'she',
  'him',
  'they',
  'them',
  'this',
  'that',
  'with',
  'have',
  'from',
  'your',
  'will',
  'would',
  'there',
  'their',
  'what',
  'when',
  'were',
  'been',
  'than',
  'then',
  'into',
  'more',
  'some',
  'such',
  'only',
  'over',
  'also',
  'just',
  'like',
  'about',
  'which',
  'while',
  'these',
  'those',
  'because',
  'could',
  'should',
  'where',
  'after',
  'before',
  'here',
  'very',
  'much',
  'many',
  'most',
  'each',
  'other',
  'being',
  'does',
  'doing',
  'down',
  'off',
  'own',
  'same',
  'too',
  'now',
  'get',
  'got',
  'via',
  'per',
};
