import 'package:grabbit/core/things/schema_org_vocabulary.dart';
import 'package:grabbit/core/things/thing_doc.dart';

/// Advisory result of validating a [ThingDoc] against the schema.org vocabulary
/// (ADR-0001, "validate at the boundary"). It is **never** an exception — the
/// caller (the P14c projection, a future import path) decides what to do.
class ThingValidation {
  const ThingValidation({
    required this.typeKnown,
    required this.unknownProperties,
  });

  /// Whether the Thing's `@type` is a known schema.org class.
  final bool typeKnown;

  /// Bare property names on the Thing not defined on its type — excludes JSON-LD
  /// keywords (`@…`) and the `grabbit:` extension namespace. Empty when the type
  /// is unknown (nothing to validate against).
  final List<String> unknownProperties;

  /// True when the type is known and every (non-ignored) property is defined.
  bool get isValid => typeKnown && unknownProperties.isEmpty;
}

/// Validates [doc] against [vocab] — advisory, never throws (CLAUDE.md §8).
ThingValidation validateThingDoc(ThingDoc doc, SchemaOrgVocabulary vocab) {
  final type = doc.type;
  final typeKnown = type.isNotEmpty && vocab.isKnownType(type);
  final unknown = <String>[];
  if (typeKnown) {
    final defined = vocab.propertiesFor(type);
    for (final key in doc.json.keys) {
      if (_isIgnoredKey(key)) continue;
      final local = schemaLocalName(key);
      if (local.isNotEmpty && !defined.contains(local)) unknown.add(local);
    }
  }
  return ThingValidation(typeKnown: typeKnown, unknownProperties: unknown);
}

/// JSON-LD keywords and GrabBit's extension namespace are never schema.org
/// properties, so validation ignores them (ADR-0004 provenance lives in `grabbit:`).
bool _isIgnoredKey(String key) =>
    key.startsWith('@') || key.startsWith('grabbit:');
