/// Pure, engine-free helpers for the "Ask your library" chat (P13d-2a): turning
/// persisted messages into bounded RAG history, the citation persistence codec,
/// and splitting an answer into tappable `[n]` citation spans. Kept out of the
/// controller/UI so they're unit-testable in isolation.
library;

import 'dart:convert';

import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/device/device_profile.dart';
import 'package:grabbit/features/ai/data/rag_context.dart';

const String kRoleUser = 'user';
const String kRoleAssistant = 'assistant';

/// Character budget for the recent-history window fed back into each turn's
/// prompt (the d-1 `fitHistory` knob), scaled by device tier (P13d-3): a shallow
/// window on memory-constrained mid devices (small models + the live HNSW index
/// share RAM), deeper on high. `low` never reaches generation (retrieval-only),
/// but is defined for totality.
int historyBudgetForTier(DeviceTier tier) => switch (tier) {
  DeviceTier.low || DeviceTier.mid => 1000,
  DeviceTier.high => 3000,
};

/// A decoded citation persisted on an assistant message — enough to render and
/// deep-link the inline `[n]` markers without re-running retrieval.
class Citation {
  const Citation({
    required this.index,
    required this.itemId,
    required this.title,
  });

  final int index;
  final String itemId;
  final String title;
}

/// One piece of a rendered answer: literal [text], plus a non-null [citation]
/// when this piece is a tappable `[n]` marker.
class CitationSpan {
  const CitationSpan.text(this.text) : citation = null;
  const CitationSpan.cite(this.text, Citation this.citation);

  final String text;
  final Citation? citation;

  bool get isCitation => citation != null;
}

/// Pairs consecutive user→assistant messages into RAG history turns. An
/// assistant message with no preceding question is ignored; a trailing,
/// not-yet-answered user message (e.g. the in-flight turn) is dropped.
List<RagChatTurn> messagesToHistory(List<ChatMessage> msgs) {
  final turns = <RagChatTurn>[];
  String? pendingQuestion;
  for (final m in msgs) {
    if (m.role == kRoleUser) {
      pendingQuestion = m.content;
    } else if (m.role == kRoleAssistant && pendingQuestion != null) {
      turns.add(RagChatTurn(question: pendingQuestion, answer: m.content));
      pendingQuestion = null;
    }
  }
  return turns;
}

/// Serializes the retrieved [sources] to the compact JSON stored on an assistant
/// message's `citationsJson` (only `index`/`itemId`/`title` — the snippet the
/// model saw isn't needed to render citations).
String encodeCitations(List<RagSource> sources) => jsonEncode([
  for (final s in sources) {'i': s.index, 'id': s.itemId, 'title': s.title},
]);

/// Inverse of [encodeCitations]; tolerant of null/blank/malformed input
/// (returns an empty list rather than throwing at a UI boundary).
List<Citation> decodeCitations(String? json) {
  if (json == null || json.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return [
      for (final e in decoded)
        if (e is Map &&
            e['i'] is int &&
            e['id'] is String &&
            e['title'] is String)
          Citation(
            index: e['i'] as int,
            itemId: e['id'] as String,
            title: e['title'] as String,
          ),
    ];
  } on FormatException {
    return const [];
  }
}

final _citationMarker = RegExp(r'\[(\d+)\]');

/// Splits [answer] into text + citation spans. A `[n]` whose number matches a
/// known citation becomes a tappable span; an out-of-range `[n]` stays plain
/// text so nothing is dropped.
List<CitationSpan> parseCitationSpans(String answer, List<Citation> citations) {
  final byIndex = {for (final c in citations) c.index: c};
  final spans = <CitationSpan>[];
  var cursor = 0;
  for (final match in _citationMarker.allMatches(answer)) {
    final citation = byIndex[int.parse(match.group(1)!)];
    if (citation == null) continue; // leave unknown [n] in the surrounding text
    if (match.start > cursor) {
      spans.add(CitationSpan.text(answer.substring(cursor, match.start)));
    }
    spans.add(CitationSpan.cite(match.group(0)!, citation));
    cursor = match.end;
  }
  if (cursor < answer.length) {
    spans.add(CitationSpan.text(answer.substring(cursor)));
  }
  return spans;
}
