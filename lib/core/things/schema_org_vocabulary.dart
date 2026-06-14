import 'dart:convert';

import 'package:grabbit/core/things/thing_doc.dart' show schemaLocalName;

/// A parsed, indexed view of the **schema.org vocabulary** (ADR-0001), built from
/// the vendored `schemaorg-current-https.jsonld` asset. Pure — no Flutter/asset
/// deps: construct via [SchemaOrgVocabulary.parse] with the file's contents so it's
/// unit-testable with a small fixture.
///
/// Indexes only what boundary validation needs: the known **classes** (+ their
/// `rdfs:subClassOf` parents, for inherited properties) and which **properties** are
/// declared on which class (`schema:domainIncludes`). The raw decoded JSON is
/// dropped after indexing to keep memory lean.
class SchemaOrgVocabulary {
  SchemaOrgVocabulary._(this._superClasses, this._propsByDomain);

  /// Parses a schema.org JSON-LD document (`{@graph: [...]}`). Robust to JSON-LD
  /// shape: `@type` / `rdfs:subClassOf` / `schema:domainIncludes` may each be a
  /// single value or a list.
  factory SchemaOrgVocabulary.parse(String json) {
    final decoded = jsonDecode(json);
    final graph = decoded is Map<String, dynamic> ? decoded['@graph'] : null;
    final superClasses = <String, Set<String>>{};
    final propsByDomain = <String, Set<String>>{};
    if (graph is List) {
      for (final node in graph) {
        if (node is! Map) continue;
        // Discriminate on the raw @type ('rdfs:Class' / 'rdf:Property'); other
        // @types (e.g. enumeration members like `schema:MedicalSpecialty`) are
        // individuals, not types/properties, and are skipped.
        final rawTypes = _asList(node['@type']).map((e) => '$e').toSet();
        final id = schemaLocalName(node['@id']);
        if (id.isEmpty) continue;
        if (rawTypes.contains('rdfs:Class')) {
          superClasses[id] = {
            for (final s in _asList(node['rdfs:subClassOf']))
              if (schemaLocalName(s).isNotEmpty) schemaLocalName(s),
          };
        }
        if (rawTypes.contains('rdf:Property')) {
          for (final dom in _asList(node['schema:domainIncludes'])) {
            final cls = schemaLocalName(dom);
            if (cls.isNotEmpty) (propsByDomain[cls] ??= <String>{}).add(id);
          }
        }
      }
    }
    return SchemaOrgVocabulary._(superClasses, propsByDomain);
  }

  /// class local-name → direct superclass local-names.
  final Map<String, Set<String>> _superClasses;

  /// class local-name → property local-names declared with that class in domain.
  final Map<String, Set<String>> _propsByDomain;

  /// Number of known classes (≈1010 in schema.org v30.0).
  int get typeCount => _superClasses.length;

  /// Whether [type] (bare or prefixed) is a known schema.org class.
  bool isKnownType(String type) =>
      _superClasses.containsKey(schemaLocalName(type));

  /// All property local-names valid on [type] — those declared on it **and** any
  /// inherited from ancestor classes via `subClassOf`. Empty if [type] is unknown.
  Set<String> propertiesFor(String type) {
    final start = schemaLocalName(type);
    if (!_superClasses.containsKey(start)) return const {};
    final props = <String>{};
    final seen = <String>{};
    final queue = <String>[start];
    while (queue.isNotEmpty) {
      final cls = queue.removeLast();
      if (!seen.add(cls)) continue;
      props.addAll(_propsByDomain[cls] ?? const {});
      queue.addAll(_superClasses[cls] ?? const {});
    }
    return props;
  }

  /// Whether [property] is defined on [type] (directly or inherited).
  bool isDefined(String type, String property) =>
      propertiesFor(type).contains(schemaLocalName(property));

  static List<Object?> _asList(Object? v) => switch (v) {
    null => const [],
    final List<Object?> list => list,
    _ => [v],
  };
}
