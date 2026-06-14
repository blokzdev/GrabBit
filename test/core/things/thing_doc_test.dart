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
}
