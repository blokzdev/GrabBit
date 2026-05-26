import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/utils/image_dimensions.dart';
import 'package:image/image.dart' as img;

void main() {
  test('reads dimensions from a PNG header without a full decode', () {
    final png = img.encodePng(img.Image(width: 320, height: 240));
    expect(imageDimensions(png), (320, 240));
  });

  test('reads dimensions from a JPEG', () {
    final jpg = img.encodeJpg(img.Image(width: 64, height: 48));
    expect(imageDimensions(jpg), (64, 48));
  });

  test('returns null for non-image bytes', () {
    expect(imageDimensions(Uint8List.fromList([1, 2, 3, 4, 5])), isNull);
    expect(imageDimensions(Uint8List(0)), isNull);
  });
}
