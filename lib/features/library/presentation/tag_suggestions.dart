/// Pure, engine-free helpers for on-device LLM tag suggestions (P13c). Kept out
/// of the controller/widget so the prompt shape and the (forgiving) parser are
/// unit-testable in isolation (mirrors `ai_summary.dart`).
library;

/// System instruction for tag suggestions — biases toward a few short, topical
/// tags as a plain comma-separated list. On-device; nothing leaves the device.
const String kTagSystemPrompt =
    'You suggest concise topical tags for a piece of media. Reply with 5–8 '
    'short lowercase tags (1–2 words each) as a single comma-separated list, '
    'and nothing else. Use only what the content is about; no hashtags, no '
    'numbering, no sentences.';

/// Builds the (system, user) prompt pair for suggesting tags from [text].
/// The source is head-truncated to [maxChars] (small on-device models have a
/// limited context window).
({String systemPrompt, String prompt}) buildTagPrompt(
  String text, {
  int maxChars = 3000,
}) {
  final trimmed = text.trim();
  final source = trimmed.length > maxChars
      ? trimmed.substring(0, maxChars).trimRight()
      : trimmed;
  return (
    systemPrompt: kTagSystemPrompt,
    prompt: 'Suggest tags for the following:\n\n$source',
  );
}

/// Parses a model's free-text reply into clean tag suggestions. Forgiving by
/// design: splits on commas/newlines/semicolons, strips `#`/quotes/bullets,
/// collapses whitespace, lowercases, drops empties and over-long entries,
/// de-duplicates (case-insensitive), removes anything in [exclude]
/// (case-insensitive), and caps to [max].
List<String> parseTagSuggestions(
  String raw, {
  Set<String> exclude = const {},
  int max = 8,
  int maxLen = 30,
}) {
  final excluded = {for (final e in exclude) e.trim().toLowerCase()};
  final seen = <String>{};
  final out = <String>[];
  for (final part in raw.split(RegExp(r'[,\n;]'))) {
    var tag = part.trim().toLowerCase();
    // Strip leading bullets/numbering/hashes and surrounding quotes.
    tag = tag
        .replaceAll(RegExp(r'''^[\s\-*#0-9.\)"'`]+'''), '')
        .replaceAll(RegExp(r'''["'`]+$'''), '')
        .trim();
    if (tag.isEmpty || tag.length > maxLen) continue;
    if (excluded.contains(tag) || !seen.add(tag)) continue;
    out.add(tag);
    if (out.length >= max) break;
  }
  return out;
}
