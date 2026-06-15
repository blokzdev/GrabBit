import 'dart:convert';

import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/core/things/schema_org_vocabulary.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/core/things/thing_validation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// **Direct-parse** — the curator's branch (a) (ADR-0002): read already-structured
/// markup out of a captured page into typed schema.org [ThingDoc]s with **zero
/// inference**. Pure (no I/O): the caller fetches the HTML; this only parses. Runs
/// on **every device** — the device-universal capture floor (`docs/things-engine.md`).
///
/// Extraction prefers the **richest typed `@type`**: JSON-LD → microdata →
/// OpenGraph/meta. (SEO link-preview libraries go OpenGraph-first for a title+image;
/// the Things Engine instead wants a real `@type` — a `Recipe`, not a `WebPage`.)
/// Returns candidates **best-first**; an empty list means nothing structured was found.
List<ThingDoc> directParse(
  String html, {
  required String sourceRef,
  required SchemaOrgVocabulary vocab,
  DateTime Function() now = DateTime.now,
}) {
  final document = html_parser.parse(html);

  final raw = <_RawCandidate>[];
  var order = 0;
  for (final node in _jsonLdNodes(document)) {
    raw.add(_RawCandidate(node, _Source.jsonLd, order++));
  }
  for (final node in _microdataNodes(document)) {
    raw.add(_RawCandidate(node, _Source.microdata, order++));
  }
  final og = _openGraphNode(document);
  if (og != null) raw.add(_RawCandidate(og, _Source.openGraph, order++));

  final ranked = <_Ranked>[];
  for (final candidate in raw) {
    final type = _chooseType(candidate.json['@type'], vocab);
    if (type.isEmpty) continue;
    final doc = _finalize(candidate.json, type, vocab, sourceRef, now);
    if (doc == null) continue;
    ranked.add(
      _Ranked(doc, _rankOf(type, candidate.source, vocab), candidate.order),
    );
  }
  ranked.sort((a, b) {
    final byRank = a.rank.compareTo(b.rank);
    return byRank != 0 ? byRank : a.order.compareTo(b.order);
  });
  return [for (final r in ranked) r.doc];
}

enum _Source { jsonLd, microdata, openGraph }

class _RawCandidate {
  _RawCandidate(this.json, this.source, this.order);
  final Map<String, dynamic> json;
  final _Source source;
  final int order;
}

class _Ranked {
  _Ranked(this.doc, this.rank, this.order);
  final ThingDoc doc;
  final int rank;
  final int order;
}

/// Page-structure types that describe the *page*, not the captured thing — ranked
/// below real content types so a `WebPage` wrapping a `Recipe` never wins.
const Set<String> _containerTypes = {
  'WebPage',
  'WebSite',
  'CollectionPage',
  'ItemList',
  'BreadcrumbList',
  'SearchAction',
  'Organization',
  'SiteNavigationElement',
  'WPHeader',
  'WPFooter',
};

/// Lower is better: content beats containers; known types beat unknown; and within
/// a tie, JSON-LD beats microdata beats OpenGraph.
int _rankOf(String type, _Source source, SchemaOrgVocabulary vocab) {
  final sourceRank = switch (source) {
    _Source.jsonLd => 0,
    _Source.microdata => 1,
    _Source.openGraph => 2,
  };
  final container = _containerTypes.contains(type) ? 1 : 0;
  final known = vocab.isKnownType(type) ? 0 : 1;
  return container * 100 + known * 10 + sourceRank;
}

/// Assembles one canonical [ThingDoc] from a raw node map: normalize `@context`/
/// `@type`, copy substantive properties, drop ones not defined on a known type
/// (boundary validation, ADR-0001), and stamp `direct-parse` provenance. Returns
/// null when nothing substantive survives.
ThingDoc? _finalize(
  Map<String, dynamic> node,
  String type,
  SchemaOrgVocabulary vocab,
  String sourceRef,
  DateTime Function() now,
) {
  final out = <String, dynamic>{
    '@context': 'https://schema.org',
    '@type': type,
  };
  node.forEach((key, value) {
    if (key.startsWith('@') || key.startsWith('grabbit:')) return;
    final local = schemaLocalName(key);
    if (local.isEmpty) return;
    final cleaned = _clean(value);
    if (cleaned != null) out[local] = cleaned;
  });

  // Drop properties not defined on the type (no-op when the type is unknown — the
  // long tail is kept whole; ADR-0001).
  final validation = validateThingDoc(ThingDoc(out), vocab);
  for (final prop in validation.unknownProperties) {
    out.remove(prop);
  }

  if (!out.keys.any((k) => !k.startsWith('@'))) return null;

  out[kGrabbitProvenanceKey] = grabbitProvenanceBlock(
    provenance: Provenance.directParse,
    capturedAt: now(),
    sourceRef: sourceRef,
  );
  return ThingDoc(out);
}

// --- JSON-LD ----------------------------------------------------------------

List<Map<String, dynamic>> _jsonLdNodes(Document document) {
  final out = <Map<String, dynamic>>[];
  for (final script in document.querySelectorAll('script')) {
    if ((script.attributes['type'] ?? '').toLowerCase() !=
        'application/ld+json') {
      continue;
    }
    final text = script.text.trim();
    if (text.isEmpty) continue;
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      continue; // malformed block — skip, never throw.
    }
    _collectJsonLd(decoded, out);
  }
  return out;
}

void _collectJsonLd(Object? decoded, List<Map<String, dynamic>> out) {
  if (decoded is List) {
    for (final e in decoded) {
      _collectJsonLd(e, out);
    }
    return;
  }
  if (decoded is! Map) return;
  final map = Map<String, dynamic>.from(decoded);

  final graph = map['@graph'];
  if (graph is List) {
    for (final e in graph) {
      _collectJsonLd(e, out);
    }
    if (!map.containsKey('@type')) return; // a pure {@context, @graph} wrapper.
  }

  if (map['@type'] != null) {
    out.add(map);
    // Surface a nested primary entity as its own candidate (a `WebPage` whose
    // `mainEntity` is the actual `Recipe`).
    for (final key in const ['mainEntity', 'mainEntityOfPage']) {
      final nested = map[key];
      if (nested is Map && nested['@type'] != null) {
        out.add(Map<String, dynamic>.from(nested));
      }
    }
  }
}

// --- Microdata --------------------------------------------------------------

List<Map<String, dynamic>> _microdataNodes(Document document) {
  final out = <Map<String, dynamic>>[];
  for (final el in document.querySelectorAll('[itemscope]')) {
    if (_hasItemscopeAncestor(el)) continue; // only top-level items.
    final item = _parseMicrodataItem(el);
    if (item != null) out.add(item);
  }
  return out;
}

bool _hasItemscopeAncestor(Element el) {
  for (var p = el.parent; p != null; p = p.parent) {
    if (p.attributes.containsKey('itemscope')) return true;
  }
  return false;
}

Map<String, dynamic>? _parseMicrodataItem(Element scope) {
  final itemtype = scope.attributes['itemtype'];
  if (itemtype == null) return null;
  final type = schemaLocalName(itemtype.trim().split(RegExp(r'\s+')).first);
  if (type.isEmpty) return null;
  final node = <String, dynamic>{'@type': type};
  for (final child in scope.children) {
    _visitMicrodata(child, node);
  }
  return node;
}

void _visitMicrodata(Element el, Map<String, dynamic> node) {
  final isScope = el.attributes.containsKey('itemscope');
  final prop = el.attributes['itemprop']?.trim();
  if (prop != null && prop.isNotEmpty) {
    final Object? value = isScope
        ? _parseMicrodataItem(el)
        : _microdataValue(el);
    if (value != null) {
      for (final name in prop.split(RegExp(r'\s+'))) {
        _addMulti(node, name, value);
      }
    }
  }
  // A nested item's properties belong to it, not its parent.
  if (isScope) return;
  for (final child in el.children) {
    _visitMicrodata(child, node);
  }
}

String? _microdataValue(Element el) {
  final raw = switch (el.localName) {
    'meta' => el.attributes['content'],
    'a' || 'link' || 'area' => el.attributes['href'],
    'img' ||
    'audio' ||
    'video' ||
    'source' ||
    'iframe' ||
    'embed' ||
    'track' => el.attributes['src'],
    'object' => el.attributes['data'],
    'data' || 'meter' => el.attributes['value'],
    'time' => el.attributes['datetime'] ?? el.text,
    _ => el.text,
  };
  final v = raw?.trim();
  return (v == null || v.isEmpty) ? null : v;
}

void _addMulti(Map<String, dynamic> node, String key, Object value) {
  final existing = node[key];
  if (existing == null) {
    node[key] = value;
  } else if (existing is List) {
    existing.add(value);
  } else {
    node[key] = [existing, value];
  }
}

// --- OpenGraph / meta -------------------------------------------------------

Map<String, dynamic>? _openGraphNode(Document document) {
  final og = <String, String>{};
  for (final meta in document.querySelectorAll('meta')) {
    final prop = meta.attributes['property'] ?? meta.attributes['name'];
    final content = meta.attributes['content']?.trim();
    if (prop == null || content == null || content.isEmpty) continue;
    if (prop.startsWith('og:')) {
      og.putIfAbsent(prop, () => content);
    } else if (prop == 'description') {
      og.putIfAbsent('description', () => content);
    }
  }

  final hasOg = og.keys.any((k) => k.startsWith('og:'));
  final hasDescription = og.containsKey('description');
  // A lone <title> is too thin to count as a captured Thing — require real
  // OpenGraph or a meta description before falling back to it.
  if (!hasOg && !hasDescription) return null;

  final title = og['og:title'] ?? document.querySelector('title')?.text.trim();
  final description = og['og:description'] ?? og['description'];
  return <String, dynamic>{
    '@type': _ogTypeToSchema(og['og:type']),
    if (title != null && title.isNotEmpty) 'name': title,
    if (og['og:url'] != null) 'url': og['og:url'],
    if (description != null && description.isNotEmpty)
      'description': description,
    if (og['og:image'] != null) 'image': og['og:image'],
  };
}

/// Maps the loose `og:type` vocabulary onto a schema.org type; defaults to the
/// generic `WebPage` (rendered via the key/value view — ADR-0001).
String _ogTypeToSchema(String? ogType) {
  final t = (ogType ?? '').toLowerCase();
  if (t.startsWith('article')) return 'Article';
  if (t.startsWith('video')) return 'VideoObject';
  if (t.startsWith('music')) return 'AudioObject';
  if (t.startsWith('book')) return 'Book';
  if (t.startsWith('product')) return 'Product';
  if (t == 'profile') return 'Person';
  return 'WebPage';
}

// --- shared -----------------------------------------------------------------

/// Resolves a `@type` (a String or a List) to one bare local name, preferring the
/// **most specific known** class (the one with the most properties — a subclass
/// inherits a superset), so `["Thing", "Recipe"]` → `Recipe`. Falls back to the
/// first entry when none are known (long-tail types render generically).
String _chooseType(Object? raw, SchemaOrgVocabulary vocab) {
  final candidates = (raw is List ? raw : [raw])
      .map(schemaLocalName)
      .where((s) => s.isNotEmpty)
      .toList();
  if (candidates.isEmpty) return '';
  String? best;
  var bestProps = -1;
  for (final c in candidates) {
    if (!vocab.isKnownType(c)) continue;
    final count = vocab.propertiesFor(c).length;
    if (count > bestProps) {
      best = c;
      bestProps = count;
    }
  }
  return best ?? candidates.first;
}

/// Drops null / blank / empty values; trims strings; filters blank list entries;
/// passes nested objects through untouched (mirrors the curator's cleaner).
Object? _clean(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }
  if (value is List) {
    final cleaned = value.map(_clean).where((e) => e != null).toList();
    return cleaned.isEmpty ? null : cleaned;
  }
  return value;
}
