import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/core/things/vocabulary_edges.dart';

void main() {
  group('deriveVocabularyEdges', () {
    test('emits one edge per @id-bearing object reference', () {
      const doc = ThingDoc({
        '@type': 'Recipe',
        'name': 'Soup', // scalar — not an edge
        'isPartOf': {'@type': 'CreativeWork', '@id': 'collection-1'},
      });
      expect(deriveVocabularyEdges('recipe-1', doc), [
        const VocabularyEdge(
          subject: 'recipe-1',
          predicate: 'isPartOf',
          object: 'collection-1',
        ),
      ]);
    });

    test('expands a list of references into one edge each', () {
      const doc = ThingDoc({
        '@type': 'VideoObject',
        'about': [
          {'@id': 'topic-1'},
          {'@id': 'topic-2'},
        ],
      });
      final edges = deriveVocabularyEdges('v1', doc);
      expect(edges.map((e) => e.object), ['topic-1', 'topic-2']);
      expect(edges.every((e) => e.predicate == 'about'), isTrue);
    });

    test('ignores inline nodes without an @id (no Thing to point at)', () {
      const doc = ThingDoc({
        '@type': 'VideoObject',
        'author': {'@type': 'Person', 'name': 'A Channel'}, // no @id
      });
      expect(deriveVocabularyEdges('v1', doc), isEmpty);
    });

    test('skips JSON-LD keywords and the grabbit: namespace', () {
      const doc = ThingDoc({
        '@type': 'VideoObject',
        '@id': 'self',
        'grabbit:provenance': {'@id': 'should-be-ignored'},
      });
      expect(deriveVocabularyEdges('v1', doc), isEmpty);
    });

    test('strips a schema.org prefix from the predicate', () {
      const doc = ThingDoc({
        '@type': 'CreativeWork',
        'https://schema.org/isBasedOn': {'@id': 'work-2'},
      });
      expect(deriveVocabularyEdges('w1', doc).single.predicate, 'isBasedOn');
    });

    test('a bare document yields no edges', () {
      expect(
        deriveVocabularyEdges(
          'x',
          const ThingDoc({'@type': 'Thing', 'name': 'X'}),
        ),
        isEmpty,
      );
    });

    test('order follows document order (deterministic)', () {
      const doc = ThingDoc({
        '@type': 'CreativeWork',
        'isPartOf': {'@id': 'a'},
        'about': {'@id': 'b'},
      });
      expect(deriveVocabularyEdges('w', doc).map((e) => e.predicate), [
        'isPartOf',
        'about',
      ]);
    });
  });
}
