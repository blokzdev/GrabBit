import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/core/things/thing_doc.dart';

void main() {
  group('Provenance wire values', () {
    test('round-trip through fromWire for every value', () {
      for (final p in Provenance.values) {
        expect(Provenance.fromWire(p.wire), p);
      }
    });

    test('uses the ADR-0004 hyphenated spellings', () {
      expect(Provenance.directParse.wire, 'direct-parse');
      expect(Provenance.userAuthored.wire, 'user-authored');
      expect(Provenance.aiInferred.wire, 'ai-inferred');
      expect(Provenance.vectorSimilarity.wire, 'vector-similarity');
    });

    test('fromWire returns null for an unknown value', () {
      expect(Provenance.fromWire('nonsense'), isNull);
    });
  });

  group('grabbitProvenanceBlock', () {
    test('emits the kind + ISO-8601 capturedAt, omitting null fields', () {
      final block = grabbitProvenanceBlock(
        provenance: Provenance.directParse,
        capturedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      );
      expect(block, {
        'provenance': 'direct-parse',
        'capturedAt': '2026-01-02T03:04:05.000Z',
      });
      expect(block.containsKey('sourceRef'), isFalse);
      expect(block.containsKey('modelId'), isFalse);
      expect(block.containsKey('confidence'), isFalse);
    });

    test('includes the optional fields when present', () {
      final block = grabbitProvenanceBlock(
        provenance: Provenance.aiInferred,
        capturedAt: DateTime.utc(2026),
        sourceRef: 'thing-1',
        modelId: 'gemma-x',
        confidence: 0.8,
      );
      expect(block['sourceRef'], 'thing-1');
      expect(block['modelId'], 'gemma-x');
      expect(block['confidence'], 0.8);
    });
  });

  group('provenanceOf', () {
    test('reads the kind back out of a Thing document', () {
      final doc = ThingDoc({
        '@type': 'VideoObject',
        kGrabbitProvenanceKey: grabbitProvenanceBlock(
          provenance: Provenance.directParse,
          capturedAt: DateTime.utc(2026),
        ),
      });
      expect(provenanceOf(doc), Provenance.directParse);
    });

    test('returns null when the block is absent or malformed', () {
      expect(provenanceOf(const ThingDoc({'@type': 'VideoObject'})), isNull);
      expect(
        provenanceOf(const ThingDoc({kGrabbitProvenanceKey: 'not-a-map'})),
        isNull,
      );
      expect(
        provenanceOf(
          const ThingDoc({kGrabbitProvenanceKey: <String, dynamic>{}}),
        ),
        isNull,
      );
    });
  });
}
