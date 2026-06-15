import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/features/library/data/thing_exporters.dart';

void main() {
  group('exportKindFor', () {
    test('maps priority types to their export kind', () {
      expect(exportKindFor('Recipe'), ThingExportKind.text);
      expect(exportKindFor('Article'), ThingExportKind.text);
      expect(exportKindFor('Product'), ThingExportKind.text);
      expect(exportKindFor('Event'), ThingExportKind.icsFile);
      expect(exportKindFor('Place'), ThingExportKind.geoUri);
    });

    test('returns null for the long tail', () {
      expect(exportKindFor('Book'), isNull);
      expect(exportKindFor('VideoObject'), isNull);
    });
  });

  test('recipeToText lists ingredients and numbered steps', () {
    const doc = ThingDoc({
      '@type': 'Recipe',
      'name': 'Carbonara',
      'recipeYield': '4',
      'recipeIngredient': ['eggs', 'guanciale'],
      'recipeInstructions': ['Boil pasta', 'Mix'],
      'url': 'https://x.test/r',
    });
    final text = recipeToText(doc);
    expect(text, contains('Carbonara'));
    expect(text, contains('Serves: 4'));
    expect(text, contains('• eggs'));
    expect(text, contains('1. Boil pasta'));
    expect(text, contains('2. Mix'));
    expect(text, contains('https://x.test/r'));
  });

  test('productToText includes brand, price and gtin', () {
    const doc = ThingDoc({
      '@type': 'Product',
      'name': 'Widget',
      'brand': 'Acme',
      'offers': '29.99 USD',
      'gtin': '036000291452',
    });
    final text = productToText(doc);
    expect(text, contains('Widget'));
    expect(text, contains('Brand: Acme'));
    expect(text, contains('Price: 29.99 USD'));
    expect(text, contains('GTIN: 036000291452'));
  });

  test('placeToGeoUri encodes the address as a geo query', () {
    const doc = ThingDoc({
      '@type': 'Place',
      'name': 'Cafe',
      'address': '1 Main St, Town',
    });
    expect(placeToGeoUri(doc), 'geo:0,0?q=1%20Main%20St%2C%20Town');
  });

  test('placeToGeoUri falls back to name, null when neither present', () {
    expect(
      placeToGeoUri(const ThingDoc({'@type': 'Place', 'name': 'Cafe'})),
      'geo:0,0?q=Cafe',
    );
    expect(placeToGeoUri(const ThingDoc({'@type': 'Place'})), isNull);
  });

  group('eventToIcs', () {
    test('emits a VEVENT with escaped fields and UTC datetimes', () {
      const doc = ThingDoc({
        '@type': 'Event',
        'name': 'Dart, Conf',
        'description': 'Line1\nLine2',
        'startDate': '2026-06-20T09:00:00Z',
        'endDate': '2026-06-21T17:00:00Z',
        'location': 'San Francisco',
      });
      final ics = eventToIcs(
        doc,
        uid: 'thing_1',
        now: () => DateTime.utc(2026, 1, 2, 3, 4, 5),
      );
      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('UID:thing_1@grabbit'));
      expect(ics, contains('DTSTAMP:20260102T030405Z'));
      expect(ics, contains('DTSTART:20260620T090000Z'));
      expect(ics, contains('DTEND:20260621T170000Z'));
      expect(ics, contains(r'SUMMARY:Dart\, Conf'));
      expect(ics, contains(r'DESCRIPTION:Line1\nLine2'));
      expect(ics, contains('END:VCALENDAR'));
    });

    test('a date-only startDate emits a compact date', () {
      const doc = ThingDoc({
        '@type': 'Event',
        'name': 'Holiday',
        'startDate': '2026-12-25',
      });
      final ics = eventToIcs(doc, uid: 'e', now: () => DateTime.utc(2026));
      expect(ics, contains('DTSTART:20261225'));
      expect(ics, isNot(contains('DTEND:')));
    });
  });
}
