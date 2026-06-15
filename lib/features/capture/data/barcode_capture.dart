import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/core/things/thing_doc.dart';

/// A barcode classified into a schema.org skeleton (P16b-4). [type] is `Product`
/// or `Book`; [idProp]/[idValue] is the identifier to stamp (`gtin`/`isbn`).
class BarcodeMatch {
  const BarcodeMatch({
    required this.type,
    required this.idProp,
    required this.idValue,
    required this.raw,
  });

  final String type;
  final String idProp;
  final String idValue;
  final String raw;
}

/// Classifies a scanned barcode [value] into a [BarcodeMatch], or null when it
/// isn't a product/book barcode (P16b-4) — no network lookup. ISBN (Bookland
/// `978`/`979` EAN-13, or a 10-digit ISBN-10) → `Book`/`isbn`; other valid GTINs
/// (EAN-8, UPC-A 12, EAN-13) → `Product`/`gtin`.
BarcodeMatch? classifyBarcode(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9Xx]'), '');
  // ISBN-10 (9 digits + check digit which may be 'X').
  if (digits.length == 10 && RegExp(r'^[0-9]{9}[0-9Xx]$').hasMatch(digits)) {
    return BarcodeMatch(
      type: 'Book',
      idProp: 'isbn',
      idValue: digits.toUpperCase(),
      raw: value,
    );
  }

  final numeric = value.replaceAll(RegExp(r'[^0-9]'), '');
  // ISBN-13 (Bookland EAN).
  if (numeric.length == 13 &&
      (numeric.startsWith('978') || numeric.startsWith('979'))) {
    return BarcodeMatch(
      type: 'Book',
      idProp: 'isbn',
      idValue: numeric,
      raw: value,
    );
  }
  // Other retail GTINs.
  if (numeric.length == 8 || numeric.length == 12 || numeric.length == 13) {
    return BarcodeMatch(
      type: 'Product',
      idProp: 'gtin',
      idValue: numeric,
      raw: value,
    );
  }
  return null;
}

/// Builds a user-authored skeleton [ThingDoc] from a [match] (P16b-4) — a sparse
/// `Product`/`Book` carrying its identifier and a placeholder [name] (the code,
/// so it's findable until the user renames it), stamped `user-authored`
/// provenance with `sourceRef: 'barcode-scan'`. Mirrors `buildManualThing`.
ThingDoc buildBarcodeThing(
  BarcodeMatch match, {
  DateTime Function() now = DateTime.now,
}) {
  final json = <String, dynamic>{
    '@context': 'https://schema.org',
    '@type': match.type,
    'name': match.idValue,
    match.idProp: match.idValue,
  };
  json[kGrabbitProvenanceKey] = grabbitProvenanceBlock(
    provenance: Provenance.userAuthored,
    capturedAt: now(),
    sourceRef: 'barcode-scan',
  );
  return ThingDoc(json);
}
