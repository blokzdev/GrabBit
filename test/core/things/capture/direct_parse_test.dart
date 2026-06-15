import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/things/capture/direct_parse.dart';
import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/core/things/schema_org_vocabulary.dart';
import 'package:grabbit/core/things/schema_org_vocabulary_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SchemaOrgVocabulary vocab;

  setUpAll(() async {
    vocab = SchemaOrgVocabulary.parse(
      await rootBundle.loadString(schemaOrgVocabularyAsset),
    );
  });

  List<Map<String, dynamic>> parse(String html) => [
    for (final d in directParse(
      html,
      sourceRef: 'https://example.com/page',
      vocab: vocab,
      now: () => DateTime.utc(2026, 6, 15),
    ))
      d.json,
  ];

  test('JSON-LD Recipe → one typed, provenance-stamped Recipe', () {
    const html = '''
<!doctype html><html><head>
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Recipe","name":"Carbonara",
 "recipeIngredient":["eggs","guanciale"],"bogusProp":"nope"}
</script>
</head><body></body></html>''';

    final docs = parse(html);
    expect(docs, hasLength(1));
    final json = docs.single;
    expect(json['@context'], 'https://schema.org');
    expect(json['@type'], 'Recipe');
    expect(json['name'], 'Carbonara');
    expect(json['recipeIngredient'], ['eggs', 'guanciale']);
    // Unknown property dropped at the boundary (ADR-0001).
    expect(json.containsKey('bogusProp'), isFalse);

    final prov = json[kGrabbitProvenanceKey] as Map;
    expect(prov['provenance'], Provenance.directParse.wire);
    expect(prov['sourceRef'], 'https://example.com/page');
    expect(prov['capturedAt'], '2026-06-15T00:00:00.000Z');
    // Direct-parse never carries a modelId or confidence.
    expect(prov.containsKey('modelId'), isFalse);
    expect(prov.containsKey('confidence'), isFalse);
  });

  test('@graph WebPage + Recipe → Recipe ranked over the container', () {
    const html = '''
<script type="application/ld+json">
{"@context":"https://schema.org","@graph":[
  {"@type":"WebPage","name":"Recipe page","mainEntity":{"@id":"#r"}},
  {"@type":"Recipe","@id":"#r","name":"Carbonara","recipeIngredient":["eggs"]}
]}
</script>''';

    final docs = parse(html);
    expect(docs.first['@type'], 'Recipe');
    expect(docs.map((d) => d['@type']), containsAll(['Recipe', 'WebPage']));
  });

  test('nested mainEntity object is surfaced as a candidate', () {
    const html = '''
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"WebPage","name":"x",
 "mainEntity":{"@type":"Event","name":"Concert"}}
</script>''';

    final docs = parse(html);
    expect(docs.first['@type'], 'Event');
    expect(docs.first['name'], 'Concert');
  });

  test('@type as a list resolves to the most specific known type', () {
    const html = '''
<script type="application/ld+json">
{"@context":"https://schema.org","@type":["Thing","Recipe"],
 "name":"X","recipeIngredient":["a"]}
</script>''';

    final json = parse(html).single;
    expect(json['@type'], 'Recipe');
    expect(json['recipeIngredient'], [
      'a',
    ]); // kept — defined on Recipe, not Thing.
  });

  test('OpenGraph-only page → a generic Article', () {
    const html = '''
<html><head>
<meta property="og:type" content="article">
<meta property="og:title" content="Headline">
<meta property="og:url" content="https://example.com/a">
<meta property="og:description" content="Body">
<meta property="og:image" content="https://example.com/a.jpg">
</head><body></body></html>''';

    final json = parse(html).single;
    expect(json['@type'], 'Article');
    expect(json['name'], 'Headline');
    expect(json['url'], 'https://example.com/a');
    expect(json['description'], 'Body');
    expect(json[kGrabbitProvenanceKey], isA<Map<String, dynamic>>());
  });

  test('JSON-LD wins over OpenGraph on the same page', () {
    const html = '''
<html><head>
<meta property="og:type" content="website">
<meta property="og:title" content="Site">
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Recipe","name":"Stew",
 "recipeIngredient":["beef"]}
</script>
</head><body></body></html>''';

    expect(parse(html).first['@type'], 'Recipe');
  });

  test('microdata Recipe → typed Thing', () {
    const html = '''
<div itemscope itemtype="https://schema.org/Recipe">
  <span itemprop="name">Pancakes</span>
  <span itemprop="recipeIngredient">flour</span>
  <span itemprop="recipeIngredient">milk</span>
</div>''';

    final json = parse(html).single;
    expect(json['@type'], 'Recipe');
    expect(json['name'], 'Pancakes');
    expect(json['recipeIngredient'], ['flour', 'milk']);
  });

  test('malformed ld+json is skipped, not thrown', () {
    const html = '''
<html><head>
<script type="application/ld+json">{ this is not json }</script>
</head><body><p>hello</p></body></html>''';
    expect(parse(html), isEmpty);
  });

  test('a page with nothing structured → empty list', () {
    const html = '<html><body><p>just text, no markup</p></body></html>';
    expect(parse(html), isEmpty);
  });

  test('a lone <title> is too thin to capture', () {
    const html =
        '<html><head><title>Only a title</title></head><body></body></html>';
    expect(parse(html), isEmpty);
  });
}
