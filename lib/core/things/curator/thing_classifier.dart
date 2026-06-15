import 'package:grabbit/core/things/curator/priority_types.dart';

/// The cheap signals available to classify a downloaded item into a priority type
/// (ADR-0002, branch routing). All synchronous — no I/O, no embeddings (an
/// embedder-similarity scorer is a deferred augmentation; see BACKLOG).
class ClassificationInput {
  const ClassificationInput({
    this.title,
    required this.text,
    this.host,
    this.mediaType,
    this.tags = const [],
  });

  /// The item title (a strong, short signal).
  final String? title;

  /// The body text the curator will extract from (transcript / summary /
  /// description / OCR), reused here for keyword signals.
  final String text;

  /// The source host, e.g. `www.allrecipes.com` (parsed by the caller from the
  /// item's source URL). Host hints are the strongest signal.
  final String? host;

  /// The media kind: `video` / `audio` / `image` (`MediaItems.type`).
  final String? mediaType;

  /// User/AI tags applied to the item.
  final List<String> tags;
}

/// The classifier's verdict: the candidate type(s) to offer the model and a
/// per-type confidence. One candidate → single-tool (`ToolChoice.required`);
/// 2–5 → narrowed-set (`ToolChoice.auto`).
class Classification {
  const Classification(this.candidates, this._scores);

  /// 1 (single-tool) or 2–5 (narrowed-set) priority types, most-likely first.
  final List<PriorityType> candidates;

  final Map<String, double> _scores;

  /// True when the classifier is confident enough for a single forced tool.
  bool get isSingle => candidates.length == 1;

  /// Normalized 0–1 confidence for [type] (the value stamped into provenance once
  /// the model picks a tool). Falls back to the no-signal floor for unscored types.
  double confidenceFor(String type) => _scores[type] ?? _noSignalConfidence;

  /// Representative confidence (the top candidate's).
  double get topConfidence =>
      candidates.isEmpty ? 0 : confidenceFor(candidates.first.type);
}

// Scoring weights — host match dominates, keywords accumulate, media kind nudges.
const double _wKeyword = 1;
const double _wHost = 5;
const double _wMediaType = 0.5;

// Branch thresholds.
const double _strongFloor = 3; // min winner score to force a single tool
const double _dominanceFactor = 2; // winner must ≥2× the runner-up
const double _halfSaturation = 5; // score at which confidence reaches 0.5
const double _noSignalConfidence = 0.15;
const int _maxNarrowed = 5;

double _normalize(double score) =>
    score <= 0 ? 0 : (score / (score + _halfSaturation)).clamp(0.0, 1.0);

/// Classifies [input] into candidate priority types using cheap signals. Always
/// returns ≥1 candidate when there is any catalog (no-signal items fall back to a
/// narrowed-set of all types) — suggest-don't-assert makes a low-confidence attempt
/// cheap, since the user confirms or rejects.
Classification classify(
  ClassificationInput input, {
  List<PriorityType> catalog = kPriorityTypes,
}) {
  final haystack = [
    input.title ?? '',
    input.text,
    ...input.tags,
  ].join(' ').toLowerCase();
  final host = input.host?.toLowerCase() ?? '';
  final mediaType = input.mediaType?.toLowerCase();

  final raw = <String, double>{};
  for (final t in catalog) {
    var score = 0.0;
    for (final kw in t.keywords) {
      if (haystack.contains(kw)) score += _wKeyword;
    }
    if (host.isNotEmpty && t.hostHints.any(host.contains)) score += _wHost;
    if (mediaType != null && t.mediaTypeHints.contains(mediaType)) {
      score += _wMediaType;
    }
    raw[t.type] = score;
  }

  final scored = catalog.where((t) => raw[t.type]! > 0).toList()
    ..sort((a, b) => raw[b.type]!.compareTo(raw[a.type]!));

  // No signal at all → offer all types as a narrowed-set at the floor confidence.
  if (scored.isEmpty) {
    return Classification(catalog.take(_maxNarrowed).toList(), {
      for (final t in catalog) t.type: _noSignalConfidence,
    });
  }

  final scores = {for (final t in scored) t.type: _normalize(raw[t.type]!)};

  // Confident single winner: clears the floor and at least doubles the runner-up.
  final top = raw[scored.first.type]!;
  final runnerUp = scored.length > 1 ? raw[scored[1].type]! : 0;
  if (scored.length == 1 ||
      (top >= _strongFloor && top >= _dominanceFactor * runnerUp)) {
    return Classification([scored.first], scores);
  }

  // Otherwise a narrowed-set of the top candidates.
  return Classification(scored.take(_maxNarrowed).toList(), scores);
}
