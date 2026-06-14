import 'package:grabbit/core/things/thing_doc.dart';

/// How a Thing or an authored edge came to exist (ADR-0004). Deterministic kinds
/// (`directParse`, vocabulary edges) auto-apply; machine-inferred kinds
/// (`aiSuggested`/`aiInferred`/`vectorSimilarity`) are *proposed* and gated through
/// the P11 Activity Inbox before they assert ("suggest-don't-assert").
enum Provenance {
  directParse('direct-parse'),
  singleTool('single-tool'),
  narrowedSet('narrowed-set'),
  userAuthored('user-authored'),
  aiSuggested('ai-suggested'),
  aiInferred('ai-inferred'),
  vectorSimilarity('vector-similarity');

  const Provenance(this.wire);

  /// The stable, hyphenated string persisted in JSON-LD / `thing_edges`.
  final String wire;

  /// Parses a [wire] value back to a [Provenance], or null when unrecognized.
  static Provenance? fromWire(String wire) {
    for (final p in Provenance.values) {
      if (p.wire == wire) return p;
    }
    return null;
  }
}

/// The JSON-LD key for the provenance block — under the `grabbit:` extension
/// namespace (ADR-0003/0004), which schema.org validation ignores.
const String kGrabbitProvenanceKey = 'grabbit:provenance';

/// Builds the `grabbit:provenance` block value (ADR-0004): the [provenance] wire
/// value, the optional [sourceRef] (input/page/Thing it derived from), [modelId]
/// (when a model produced it), [confidence], and [capturedAt] (ISO-8601). Null
/// fields are omitted so the block carries only what's known. For determinism,
/// pass a stable [capturedAt] (e.g. the row's `createdAt`), never `DateTime.now()`.
Map<String, dynamic> grabbitProvenanceBlock({
  required Provenance provenance,
  required DateTime capturedAt,
  String? sourceRef,
  String? modelId,
  double? confidence,
}) => {
  'provenance': provenance.wire,
  'sourceRef': ?sourceRef,
  'modelId': ?modelId,
  'confidence': ?confidence,
  'capturedAt': capturedAt.toIso8601String(),
};

/// Reads the `provenance` kind out of [doc]'s `grabbit:provenance` block, or null
/// when the block is absent/malformed/unrecognized.
Provenance? provenanceOf(ThingDoc doc) {
  final block = doc.json[kGrabbitProvenanceKey];
  if (block is! Map) return null;
  final wire = block['provenance'];
  return wire is String ? Provenance.fromWire(wire) : null;
}
