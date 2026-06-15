import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/capture/data/barcode_capture.dart';

void main() {
  group('classifyBarcode', () {
    test('978/979 EAN-13 → Book (isbn)', () {
      final m = classifyBarcode('9780306406157');
      expect(m, isNotNull);
      expect(m!.type, 'Book');
      expect(m.idProp, 'isbn');
      expect(m.idValue, '9780306406157');
    });

    test('10-digit ISBN-10 (incl. X check digit) → Book', () {
      final m = classifyBarcode('097522980X');
      expect(m!.type, 'Book');
      expect(m.idValue, '097522980X');
    });

    test('UPC-A (12 digits) → Product (gtin)', () {
      final m = classifyBarcode('036000291452');
      expect(m!.type, 'Product');
      expect(m.idProp, 'gtin');
      expect(m.idValue, '036000291452');
    });

    test('non-Bookland EAN-13 → Product', () {
      final m = classifyBarcode('4006381333931');
      expect(m!.type, 'Product');
    });

    test('EAN-8 → Product', () {
      expect(classifyBarcode('96385074')!.type, 'Product');
    });

    test('strips separators before classifying', () {
      expect(classifyBarcode('036000 291452')!.idValue, '036000291452');
    });

    test('non-product codes → null', () {
      expect(classifyBarcode('https://example.com'), isNull);
      expect(classifyBarcode('hello world'), isNull);
      expect(classifyBarcode('12345'), isNull);
    });
  });

  group('buildBarcodeThing', () {
    test('Product carries gtin + user-authored/barcode-scan provenance', () {
      final doc = buildBarcodeThing(
        const BarcodeMatch(
          type: 'Product',
          idProp: 'gtin',
          idValue: '036000291452',
          raw: '036000291452',
        ),
        now: () => DateTime.utc(2026, 6, 15),
      );
      expect(doc.json['@type'], 'Product');
      expect(doc.json['gtin'], '036000291452');
      expect(doc.json['name'], '036000291452');
      final prov = doc.json['grabbit:provenance'] as Map;
      expect(prov['provenance'], 'user-authored');
      expect(prov['sourceRef'], 'barcode-scan');
    });

    test('Book carries isbn', () {
      final doc = buildBarcodeThing(
        const BarcodeMatch(
          type: 'Book',
          idProp: 'isbn',
          idValue: '9780306406157',
          raw: '9780306406157',
        ),
      );
      expect(doc.json['@type'], 'Book');
      expect(doc.json['isbn'], '9780306406157');
    });
  });
}
