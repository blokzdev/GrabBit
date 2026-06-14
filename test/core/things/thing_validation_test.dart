import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/things/schema_org_vocabulary.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/core/things/thing_validation.dart';

const _fixture = '''
{
  "@context": {"schema": "https://schema.org/"},
  "@graph": [
    {"@id": "schema:Thing", "@type": "rdfs:Class"},
    {"@id": "schema:CreativeWork", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "schema:Thing"}},
    {"@id": "schema:MediaObject", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "schema:CreativeWork"}},
    {"@id": "schema:VideoObject", "@type": "rdfs:Class", "rdfs:subClassOf": {"@id": "schema:MediaObject"}},
    {"@id": "schema:name", "@type": "rdf:Property", "schema:domainIncludes": {"@id": "schema:Thing"}},
    {"@id": "schema:contentUrl", "@type": "rdf:Property", "schema:domainIncludes": {"@id": "schema:MediaObject"}}
  ]
}
''';

void main() {
  final vocab = SchemaOrgVocabulary.parse(_fixture);
  ThingValidation validate(String json) =>
      validateThingDoc(ThingDoc.fromJsonString(json), vocab);

  test('valid: known type + defined (incl. inherited) properties', () {
    final r = validate('{"@type":"VideoObject","name":"a","contentUrl":"u"}');
    expect(r.typeKnown, isTrue);
    expect(r.unknownProperties, isEmpty);
    expect(r.isValid, isTrue);
  });

  test('unknown type -> not valid', () {
    final r = validate('{"@type":"Nonsense","name":"a"}');
    expect(r.typeKnown, isFalse);
    expect(r.isValid, isFalse);
  });

  test('undefined property is flagged', () {
    final r = validate('{"@type":"VideoObject","recipeIngredient":"x"}');
    expect(r.typeKnown, isTrue);
    expect(r.unknownProperties, contains('recipeIngredient'));
    expect(r.isValid, isFalse);
  });

  test('tolerates @keywords and the grabbit: extension namespace', () {
    final r = validate(
      '{"@type":"VideoObject","@id":"x","@context":"c",'
      '"grabbit:provenance":{"provenance":"direct-parse"},"name":"a"}',
    );
    expect(r.unknownProperties, isEmpty);
    expect(r.isValid, isTrue);
  });

  test('never throws (advisory)', () {
    expect(() => validate('{}'), returnsNormally);
    expect(validate('{}').isValid, isFalse); // no @type
  });
}
