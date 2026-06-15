import 'package:grabbit/core/things/thing_doc.dart';

/// What kind of on-device export a Thing type supports (P16c).
enum ThingExportKind { text, icsFile, geoUri }

/// The export a [type] supports, or null for the long tail (no bespoke export).
ThingExportKind? exportKindFor(String type) => switch (type) {
  'Recipe' || 'Article' || 'Product' => ThingExportKind.text,
  'Event' => ThingExportKind.icsFile,
  'Place' => ThingExportKind.geoUri,
  _ => null,
};

String? _str(ThingDoc doc, String key) {
  final v = doc.property(key);
  if (v == null) return null;
  if (v is Map) {
    final name = (v['name'] ?? v['@id'])?.toString().trim();
    return (name == null || name.isEmpty) ? null : name;
  }
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

List<String> _list(ThingDoc doc, String key) {
  final v = doc.property(key);
  if (v is List) {
    return v
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  final s = _str(doc, key);
  return s == null ? const [] : [s];
}

void _line(StringBuffer b, String label, String? value) {
  if (value != null && value.isNotEmpty) b.writeln('$label: $value');
}

/// Recipe → shareable formatted text (title, meta, ingredients, steps).
String recipeToText(ThingDoc doc) {
  final b = StringBuffer();
  b.writeln(_str(doc, 'name') ?? 'Recipe');
  _line(b, 'Serves', _str(doc, 'recipeYield'));
  _line(b, 'Prep', _str(doc, 'prepTime'));
  _line(b, 'Cook', _str(doc, 'cookTime'));
  final ingredients = _list(doc, 'recipeIngredient');
  if (ingredients.isNotEmpty) {
    b.writeln('\nIngredients:');
    for (final i in ingredients) {
      b.writeln('• $i');
    }
  }
  final steps = _list(doc, 'recipeInstructions');
  if (steps.isNotEmpty) {
    b.writeln('\nInstructions:');
    for (var i = 0; i < steps.length; i++) {
      b.writeln('${i + 1}. ${steps[i]}');
    }
  }
  _line(b, '\nSource', _str(doc, 'url'));
  return b.toString().trim();
}

/// Article → shareable formatted text (headline, byline, summary, link).
String articleToText(ThingDoc doc) {
  final b = StringBuffer();
  b.writeln(_str(doc, 'headline') ?? _str(doc, 'name') ?? 'Article');
  _line(b, 'By', _str(doc, 'author'));
  _line(b, 'Published', _str(doc, 'datePublished'));
  final desc = _str(doc, 'description');
  if (desc != null) b.writeln('\n$desc');
  _line(b, '\nLink', _str(doc, 'url'));
  return b.toString().trim();
}

/// Product → shareable formatted text (name, brand, price, gtin, link).
String productToText(ThingDoc doc) {
  final b = StringBuffer();
  b.writeln(_str(doc, 'name') ?? 'Product');
  _line(b, 'Brand', _str(doc, 'brand'));
  _line(b, 'Price', _str(doc, 'offers'));
  _line(b, 'GTIN', _str(doc, 'gtin'));
  final desc = _str(doc, 'description');
  if (desc != null) b.writeln('\n$desc');
  _line(b, '\nLink', _str(doc, 'url'));
  return b.toString().trim();
}

/// Place → an Android `geo:` URI querying the place's address (or name), so it
/// opens in the user's maps app.
String? placeToGeoUri(ThingDoc doc) {
  final query = _str(doc, 'address') ?? _str(doc, 'name');
  if (query == null) return null;
  return 'geo:0,0?q=${Uri.encodeComponent(query)}';
}

/// Event → an RFC 5545 iCalendar (VEVENT) string for a `.ics` export.
String eventToIcs(
  ThingDoc doc, {
  required String uid,
  DateTime Function() now = DateTime.now,
}) {
  final b = StringBuffer()
    ..writeln('BEGIN:VCALENDAR')
    ..writeln('VERSION:2.0')
    ..writeln('PRODID:-//GrabBit//Things//EN')
    ..writeln('BEGIN:VEVENT')
    ..writeln('UID:$uid@grabbit')
    ..writeln('DTSTAMP:${_icsStamp(now().toUtc())}');
  final start = _icsDate(_str(doc, 'startDate'));
  if (start != null) b.writeln('DTSTART:$start');
  final end = _icsDate(_str(doc, 'endDate'));
  if (end != null) b.writeln('DTEND:$end');
  _icsLine(b, 'SUMMARY', _str(doc, 'name'));
  _icsLine(b, 'DESCRIPTION', _str(doc, 'description'));
  _icsLine(b, 'LOCATION', _str(doc, 'location'));
  _icsLine(b, 'URL', _str(doc, 'url'));
  b
    ..writeln('END:VEVENT')
    ..writeln('END:VCALENDAR');
  return b.toString();
}

void _icsLine(StringBuffer b, String prop, String? value) {
  if (value == null || value.isEmpty) return;
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll('\n', r'\n')
      .replaceAll(',', r'\,')
      .replaceAll(';', r'\;');
  b.writeln('$prop:$escaped');
}

String _icsStamp(DateTime utc) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year}${two(utc.month)}${two(utc.day)}'
      'T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

/// Formats a schema.org date/datetime string as an iCal value. A date-time →
/// UTC compact (`…T…Z`); a date-only → `VALUE=DATE`-style `yyyyMMdd`. Null when
/// unparseable.
String? _icsDate(String? iso) {
  if (iso == null) return null;
  final dt = DateTime.tryParse(iso);
  if (dt == null) return null;
  final dateOnly = !iso.contains('T');
  if (dateOnly) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}';
  }
  return _icsStamp(dt.toUtc());
}
