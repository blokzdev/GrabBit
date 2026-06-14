import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/things/schema_org_vocabulary.dart';

/// A minimal schema.org-shaped fixture: a small class hierarchy + a few properties,
/// plus an enumeration member (typed by its enum, not `rdfs:Class`).
const _fixture = '''
{
  "@context": {"schema": "https://schema.org/"},
  "@graph": [
    {"@id": "schema:Thing", "@type": "rdfs:Class"},
    {"@id": "schema:CreativeWork", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "schema:Thing"}},
    {"@id": "schema:MediaObject", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "schema:CreativeWork"}},
    {"@id": "schema:VideoObject", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "schema:MediaObject"}},
    {"@id": "schema:HowTo", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "schema:CreativeWork"}},
    {"@id": "schema:Recipe", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "schema:HowTo"}},
    {"@id": "schema:name", "@type": "rdf:Property", "schema:domainIncludes": {"@id": "schema:Thing"}},
    {"@id": "schema:contentUrl", "@type": "rdf:Property", "schema:domainIncludes": {"@id": "schema:MediaObject"}},
    {"@id": "schema:recipeIngredient", "@type": "rdf:Property", "schema:domainIncludes": [{"@id": "schema:Recipe"}]},
    {"@id": "schema:Pizza", "@type": "schema:Recipe", "rdfs:label": "an enum member, not a class"}
  ]
}
''';

void main() {
  final vocab = SchemaOrgVocabulary.parse(_fixture);

  group('SchemaOrgVocabulary.isKnownType', () {
    test('knows declared classes; is prefix-tolerant', () {
      expect(vocab.isKnownType('Recipe'), isTrue);
      expect(vocab.isKnownType('schema:VideoObject'), isTrue);
      expect(vocab.isKnownType('https://schema.org/Thing'), isTrue);
    });
    test('rejects unknowns and non-class nodes', () {
      expect(vocab.isKnownType('Nonsense'), isFalse);
      expect(
        vocab.isKnownType('Pizza'),
        isFalse,
      ); // enum member, not rdfs:Class
      expect(vocab.isKnownType('name'), isFalse); // a property, not a class
    });
  });

  group('SchemaOrgVocabulary.propertiesFor', () {
    test('includes properties inherited via subClassOf', () {
      final recipe = vocab.propertiesFor('Recipe');
      expect(recipe, contains('recipeIngredient'));
      expect(recipe, contains('name')); // inherited from Thing
      final video = vocab.propertiesFor('VideoObject');
      expect(video, contains('contentUrl')); // from MediaObject
      expect(video, contains('name')); // from Thing
      expect(video, isNot(contains('recipeIngredient')));
    });
    test('empty for an unknown type', () {
      expect(vocab.propertiesFor('Nonsense'), isEmpty);
    });
  });

  test('isDefined respects domain, inheritance, and prefixes', () {
    expect(vocab.isDefined('Recipe', 'recipeIngredient'), isTrue);
    expect(vocab.isDefined('Recipe', 'schema:name'), isTrue);
    expect(vocab.isDefined('VideoObject', 'recipeIngredient'), isFalse);
  });

  test('typeCount counts only classes', () {
    expect(vocab.typeCount, 6);
  });
}
