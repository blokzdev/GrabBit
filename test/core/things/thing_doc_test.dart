import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/things/thing_doc.dart';

void main() {
  group('ThingDoc', () {
    test(
      'parses @type (prefix-stripped), name, url, and generic properties',
      () {
        final t = ThingDoc.fromJsonString(
          '{"@context":"https://schema.org/","@type":"VideoObject",'
          '"name":"Clip","url":"https://example.com/v"}',
        );
        expect(t.type, 'VideoObject');
        expect(t.name, 'Clip');
        expect(t.url, 'https://example.com/v');
        expect(t.property('name'), 'Clip');
        expect(t.property('missing'), isNull);
      },
    );

    test(
      '@type list uses the first; missing name/url are null; round-trips',
      () {
        final t = ThingDoc.fromJsonString(
          '{"@type":["schema:Recipe","schema:Thing"]}',
        );
        expect(t.type, 'Recipe');
        expect(t.name, isNull);
        expect(t.url, isNull);
        final round = ThingDoc.fromJsonString(t.toJsonString());
        expect(round.type, 'Recipe');
      },
    );

    test('blank name is treated as absent', () {
      final t = ThingDoc.fromJsonString('{"@type":"Thing","name":"   "}');
      expect(t.name, isNull);
    });

    test('throws FormatException on non-object JSON', () {
      expect(() => ThingDoc.fromJsonString('[]'), throwsFormatException);
      expect(() => ThingDoc.fromJsonString('"x"'), throwsFormatException);
    });
  });

  group('schemaLocalName', () {
    test(
      'strips schema prefixes; passes through bare/foreign; null -> empty',
      () {
        expect(schemaLocalName('schema:Recipe'), 'Recipe');
        expect(schemaLocalName('https://schema.org/Event'), 'Event');
        expect(schemaLocalName('http://schema.org/Place'), 'Place');
        expect(schemaLocalName('Recipe'), 'Recipe');
        expect(schemaLocalName({'@id': 'schema:VideoObject'}), 'VideoObject');
        expect(schemaLocalName(null), '');
      },
    );
  });

  group('thingDisplayFields', () {
    test('skips @* / grabbit:* and joins lists', () {
      const doc = ThingDoc({
        '@type': 'Recipe',
        '@context': 'https://schema.org',
        'grabbit:provenance': {'provenance': 'single-tool'},
        'name': 'Carbonara',
        'recipeIngredient': ['eggs', 'guanciale'],
        'cookTime': 'PT20M',
      });

      final fields = thingDisplayFields(doc);

      expect(fields.map((e) => e.key), [
        'name',
        'recipeIngredient',
        'cookTime',
      ]);
      expect(
        fields.firstWhere((e) => e.key == 'recipeIngredient').value,
        'eggs, guanciale',
      );
    });

    test('drops empty values', () {
      const doc = ThingDoc({'name': '  ', 'keywords': <String>[], 'url': 'x'});
      expect(thingDisplayFields(doc).map((e) => e.key), ['url']);
    });

    test('renders nested objects via name/@id', () {
      const doc = ThingDoc({
        'author': {'@type': 'Person', 'name': 'Ada'},
        'mainEntity': {'@id': 'schema:Thing'},
      });
      final fields = thingDisplayFields(doc);
      expect(fields.firstWhere((e) => e.key == 'author').value, 'Ada');
      expect(
        fields.firstWhere((e) => e.key == 'mainEntity').value,
        'schema:Thing',
      );
    });
  });
}
