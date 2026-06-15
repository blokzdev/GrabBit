import 'dart:convert';

/// A parsed schema.org **Thing** as JSON-LD (ADR-0001). Named `ThingDoc` to avoid
/// colliding with Drift's generated `Thing` row class: the row stores
/// [toJsonString] as its canonical `jsonld`, with `name`/`url` promoted out via
/// [name]/[url].
///
/// The JSON-LD document is the single source of truth; this is a thin, immutable
/// view over it. Property access is **dynamic** — schema.org is schema-as-data,
/// not Dart classes (ADR-0001).
class ThingDoc {
  const ThingDoc(this.json);

  /// Parses [jsonString]; throws [FormatException] when it isn't a JSON object.
  factory ThingDoc.fromJsonString(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Thing JSON-LD must be a JSON object');
    }
    return ThingDoc(decoded);
  }

  /// The decoded JSON-LD object — the canonical payload. Treated as immutable.
  final Map<String, dynamic> json;

  /// The schema.org `@type` (e.g. `Recipe`, `VideoObject`), prefix-stripped; '' when
  /// absent. When `@type` is a list, the first entry is used.
  String get type => schemaLocalName(_firstOf(json['@type']));

  /// Promoted cache of `name`; null when absent or blank.
  String? get name => _trimmedString('name');

  /// Promoted cache of `url`; null when absent or blank.
  String? get url => _trimmedString('url');

  /// Generic dynamic access to a (bare schema.org) property [key].
  Object? property(String key) => json[key];

  /// Canonical JSON serialization (for the `things.jsonld` column).
  String toJsonString() => jsonEncode(json);

  String? _trimmedString(String key) {
    final v = json[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }

  static Object? _firstOf(Object? v) =>
      v is List ? (v.isEmpty ? null : v.first) : v;
}

/// The user-facing properties of a [doc] — every key except the JSON-LD keywords
/// (`@type`, `@context`, …) and GrabBit's `grabbit:` extension block. Scalars
/// stringify; lists comma-join; nested objects show their `name`/`@id`. Empty
/// values are dropped. The shared generic-render helper behind the P15d review card
/// and the P15e Things Browser (ADR-0001 schema-driven key/value view).
List<MapEntry<String, String>> thingDisplayFields(ThingDoc doc) {
  final out = <MapEntry<String, String>>[];
  doc.json.forEach((key, value) {
    if (key.startsWith('@') || key.startsWith('grabbit:')) return;
    final formatted = _formatValue(value);
    if (formatted.isEmpty) return;
    out.add(MapEntry(key, formatted));
  });
  return out;
}

String _formatValue(Object? value) {
  if (value is List) {
    return value.map(_scalar).where((s) => s.isNotEmpty).join(', ');
  }
  return _scalar(value);
}

String _scalar(Object? value) {
  if (value == null) return '';
  if (value is Map) {
    return (value['name'] ?? value['@id'] ?? '').toString().trim();
  }
  return value.toString().trim();
}

/// Strips a `schema:` / `https://schema.org/` / `http://schema.org/` prefix from a
/// schema.org IRI or CURIE, returning the bare local name (e.g. `Recipe`). Accepts a
/// `String`, a `{@id: ...}` map, or null (→ '').
String schemaLocalName(Object? iri) {
  if (iri == null) return '';
  var s = iri is Map ? (iri['@id']?.toString() ?? '') : iri.toString();
  s = s.trim();
  for (final prefix in const [
    'https://schema.org/',
    'http://schema.org/',
    'schema:',
  ]) {
    if (s.startsWith(prefix)) return s.substring(prefix.length);
  }
  return s;
}
