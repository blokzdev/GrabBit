import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/library/presentation/ocr.dart';

void main() {
  group('shouldAutoOcr (P13b-3)', () {
    test('all favourable → true', () {
      expect(
        shouldAutoOcr(
          enabled: true,
          engineAvailable: true,
          isImage: true,
          alreadyScanned: false,
        ),
        isTrue,
      );
    });

    test('any unfavourable condition → false', () {
      expect(
        shouldAutoOcr(
          enabled: false,
          engineAvailable: true,
          isImage: true,
          alreadyScanned: false,
        ),
        isFalse,
        reason: 'disabled',
      );
      expect(
        shouldAutoOcr(
          enabled: true,
          engineAvailable: false,
          isImage: true,
          alreadyScanned: false,
        ),
        isFalse,
        reason: 'engine unavailable',
      );
      expect(
        shouldAutoOcr(
          enabled: true,
          engineAvailable: true,
          isImage: false,
          alreadyScanned: false,
        ),
        isFalse,
        reason: 'not an image',
      );
      expect(
        shouldAutoOcr(
          enabled: true,
          engineAvailable: true,
          isImage: true,
          alreadyScanned: true,
        ),
        isFalse,
        reason: 'already scanned',
      );
    });
  });
}
