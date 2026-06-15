import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Boilerplate elements that never hold the main article text.
const _boilerplateTags = {
  'script',
  'style',
  'noscript',
  'nav',
  'header',
  'footer',
  'aside',
  'form',
  'template',
};

/// Cap the text fed to the curator — articles are far shorter than this, and a
/// tiny model's context is the real limit.
const int _maxTextChars = 8000;

/// Extracts the readable main text from a page's [html] for the curator fallback
/// (P16b-2) — a small pure-Dart heuristic over `package:html` (no native/widget
/// dep): strip boilerplate, prefer `<article>`/`<main>`, else pick the densest
/// content block, then collapse whitespace and cap the length. Only feeds the
/// model branch — structured pages go through direct-parse first. Returns '' when
/// nothing substantive is found.
String extractReadableText(String html) {
  final document = html_parser.parse(html);
  for (final tag in _boilerplateTags) {
    for (final el in document.querySelectorAll(tag)) {
      el.remove();
    }
  }

  final root = _mainContentElement(document);
  if (root == null) return '';
  return _collapse(root.text);
}

/// The page title for the capture (P16b-2): `og:title` first, then `<title>`.
String? extractPageTitle(String html) {
  final document = html_parser.parse(html);
  for (final meta in document.querySelectorAll('meta')) {
    final prop = meta.attributes['property'] ?? meta.attributes['name'];
    if (prop == 'og:title') {
      final content = meta.attributes['content']?.trim();
      if (content != null && content.isNotEmpty) return content;
    }
  }
  final title = document.querySelector('title')?.text.trim();
  return (title != null && title.isNotEmpty) ? title : null;
}

/// Picks the element most likely to hold the article: an explicit `<article>`/
/// `<main>` when present, otherwise the candidate block with the most text.
Element? _mainContentElement(Document document) {
  for (final selector in const ['article', 'main']) {
    final el = document.querySelector(selector);
    if (el != null && _collapse(el.text).length >= 200) return el;
  }

  Element? best;
  var bestLength = 0;
  for (final el in document.querySelectorAll('article, main, section, div')) {
    final length = _collapse(el.text).length;
    if (length > bestLength) {
      bestLength = length;
      best = el;
    }
  }
  return best ?? document.body;
}

/// Collapses runs of whitespace to single spaces and trims, capping the result.
String _collapse(String text) {
  final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return collapsed.length <= _maxTextChars
      ? collapsed
      : collapsed.substring(0, _maxTextChars);
}
