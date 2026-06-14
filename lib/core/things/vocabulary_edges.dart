import 'package:grabbit/core/things/thing_doc.dart';

/// A derived, directed Thing→Thing relationship read straight out of a Thing's
/// JSON-LD (ADR-0004 kind 1). Deterministic and rebuildable — **never stored**
/// (unlike authored edges); recomputed from the canonical document on demand.
class VocabularyEdge {
  const VocabularyEdge({
    required this.subject,
    required this.predicate,
    required this.object,
  });

  /// The id of the Thing the edge is derived from.
  final String subject;

  /// The bare schema.org property name it came from (e.g. `author`, `isPartOf`).
  final String predicate;

  /// The id (`@id`) of the referenced Thing.
  final String object;

  @override
  bool operator ==(Object other) =>
      other is VocabularyEdge &&
      other.subject == subject &&
      other.predicate == predicate &&
      other.object == object;

  @override
  int get hashCode => Object.hash(subject, predicate, object);

  @override
  String toString() => 'VocabularyEdge($subject -$predicate-> $object)';
}

/// Derives the vocabulary edges out of [doc] (a Thing with id [subjectId]) — one
/// per **object reference**: a property whose value is a JSON object carrying a
/// String `@id` (or a list of such). Detection is **structural** (the vocabulary
/// indexes `domainIncludes`/`subClassOf`, not `rangeIncludes`), so it works for any
/// schema.org property. JSON-LD keywords (`@…`) and the `grabbit:` namespace are
/// skipped. Inline nodes without an `@id` (e.g. today's MediaObject `author`) point
/// to no Thing and so yield nothing — the derivation is ready for when richer Things
/// carry `@id` references (P15/P16). Order is deterministic (document order).
List<VocabularyEdge> deriveVocabularyEdges(String subjectId, ThingDoc doc) {
  final edges = <VocabularyEdge>[];
  for (final entry in doc.json.entries) {
    final key = entry.key;
    if (key.startsWith('@') || key.startsWith('grabbit:')) continue;
    final predicate = schemaLocalName(key);
    if (predicate.isEmpty) continue;
    for (final value
        in entry.value is List ? entry.value as List : [entry.value]) {
      final object = _objectId(value);
      if (object != null) {
        edges.add(
          VocabularyEdge(
            subject: subjectId,
            predicate: predicate,
            object: object,
          ),
        );
      }
    }
  }
  return edges;
}

/// The `@id` of an object reference, or null when [value] isn't a Thing reference.
String? _objectId(Object? value) {
  if (value is Map) {
    final id = value['@id'];
    if (id is String && id.trim().isNotEmpty) return id.trim();
  }
  return null;
}
