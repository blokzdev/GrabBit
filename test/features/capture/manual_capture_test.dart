import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/features/capture/data/manual_capture.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 6, 15, 12);

  test('builds sparse JSON-LD with the chosen type and entered fields', () {
    final doc = buildManualThing(
      type: 'Recipe',
      name: 'Carbonara',
      description: 'Roman pasta',
      url: 'https://example.com/carbonara',
      now: () => fixedNow,
    );

    expect(doc.type, 'Recipe');
    expect(doc.name, 'Carbonara');
    expect(doc.json['@context'], 'https://schema.org');
    expect(doc.json['description'], 'Roman pasta');
    expect(doc.json['url'], 'https://example.com/carbonara');
  });

  test('drops blank optional fields and trims values', () {
    final doc = buildManualThing(
      type: '  NoteDigitalDocument  ',
      name: '  Buy milk  ',
      description: '   ',
      url: '',
      now: () => fixedNow,
    );

    expect(doc.type, 'NoteDigitalDocument');
    expect(doc.name, 'Buy milk');
    expect(doc.json.containsKey('description'), isFalse);
    expect(doc.json.containsKey('url'), isFalse);
  });

  test('stamps a user-authored provenance block with the manual sourceRef', () {
    final doc = buildManualThing(
      type: kManualNoteType,
      name: 'A note',
      now: () => fixedNow,
    );

    expect(provenanceOf(doc), Provenance.userAuthored);
    final block = doc.json[kGrabbitProvenanceKey] as Map;
    expect(block['sourceRef'], 'manual');
    expect(block['capturedAt'], fixedNow.toIso8601String());
  });
}
