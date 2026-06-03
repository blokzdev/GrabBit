/// Pure, engine-free building blocks for the local GraphRAG "Ask your library"
/// retrieval (P13d-1): the grounding-source + context types, the prompt builder,
/// source selection, and history-window fitting. Kept out of the retriever/UI so
/// the prompt shape + bounds are unit-testable in isolation.
library;

/// System instruction: answer only from the provided sources, cite them, and
/// admit ignorance rather than invent. On-device; nothing leaves the device.
const String kRagSystemPrompt =
    "You answer questions about the user's personal media library using ONLY "
    'the numbered sources provided. Cite the sources you use inline as [n]. If '
    'the sources do not contain the answer, say you do not know — never invent '
    'items, facts, or citations.';

/// One retrieved library item used to ground an answer. [index] is its 1-based
/// citation number; [snippet] is the compact, capped text the model sees.
class RagSource {
  const RagSource({
    required this.index,
    required this.itemId,
    required this.title,
    required this.snippet,
  });

  final int index;
  final String itemId;
  final String title;
  final String snippet;
}

/// A prior question/answer turn, for multi-turn history (fed back, bounded).
class RagChatTurn {
  const RagChatTurn({required this.question, required this.answer});
  final String question;
  final String answer;
}

/// The assembled retrieval context + prompt for one question.
class RagContext {
  const RagContext({
    required this.question,
    required this.sources,
    required this.systemPrompt,
    required this.prompt,
  });

  final String question;
  final List<RagSource> sources;
  final String systemPrompt;
  final String prompt;

  bool get hasSources => sources.isNotEmpty;
}

/// Builds a compact, capped grounding snippet for one item from its signals.
/// Prefers the distilled `aiSummary` over the raw description; includes a slice
/// of the transcript + OCR text; whole thing is truncated to [maxChars].
String buildSourceSnippet({
  String? uploader,
  List<String> tags = const [],
  String? description,
  String? transcript,
  String? aiSummary,
  String? ocrText,
  int maxChars = 400,
}) {
  String? clean(String? s) =>
      (s != null && s.trim().isNotEmpty) ? s.trim() : null;
  final parts = <String>[
    if (clean(uploader) != null) 'by ${uploader!.trim()}',
    if (tags.isNotEmpty) 'tags: ${tags.join(', ')}',
    ?(clean(aiSummary) ?? clean(description)),
    if (clean(transcript) != null) transcript!.trim(),
    if (clean(ocrText) != null) 'text in image: ${ocrText!.trim()}',
  ];
  final joined = parts.join(' · ');
  return joined.length > maxChars
      ? joined.substring(0, maxChars).trimRight()
      : joined;
}

/// De-duplicates [orderedIds] (preserving order) and caps to [max] — the final
/// source set, most-relevant first.
List<String> selectRagSources(List<String> orderedIds, {int max = 6}) {
  final seen = <String>{};
  final out = <String>[];
  for (final id in orderedIds) {
    if (seen.add(id)) out.add(id);
    if (out.length >= max) break;
  }
  return out;
}

/// Keeps the most **recent** history turns that fit within [charBudget]
/// (oldest dropped first), returned chronologically. The tier knob's mechanism:
/// a smaller budget on smaller models feeds back less history.
List<RagChatTurn> fitHistory(List<RagChatTurn> turns, int charBudget) {
  final kept = <RagChatTurn>[];
  var used = 0;
  for (final t in turns.reversed) {
    final cost = t.question.length + t.answer.length;
    if (used + cost > charBudget && kept.isNotEmpty) break;
    kept.add(t);
    used += cost;
    if (used >= charBudget) break;
  }
  return kept.reversed.toList();
}

/// Assembles the user prompt: a bounded slice of prior turns (if any), the
/// numbered sources, and the question.
String buildRagPrompt(
  String question,
  List<RagSource> sources, {
  List<RagChatTurn> history = const [],
  int historyCharBudget = 1500,
}) {
  final b = StringBuffer();
  final fitted = fitHistory(history, historyCharBudget);
  if (fitted.isNotEmpty) {
    b.writeln('Conversation so far:');
    for (final t in fitted) {
      b
        ..writeln('Q: ${t.question}')
        ..writeln('A: ${t.answer}');
    }
    b.writeln();
  }
  b.writeln('Sources:');
  for (final s in sources) {
    b.writeln('[${s.index}] ${s.title} — ${s.snippet}');
  }
  b
    ..writeln()
    ..write('Question: $question');
  return b.toString();
}
