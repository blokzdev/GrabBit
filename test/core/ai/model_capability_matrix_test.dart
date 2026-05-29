import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/model_capability_matrix.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/device/device_profile.dart';

void main() {
  group('ModelCapabilityMatrix.embedderFor', () {
    test('defaults to the Gecko floor at every tier (P12a)', () {
      const matrix = ModelCapabilityMatrix();
      for (final tier in DeviceTier.values) {
        expect(matrix.embedderFor(tier), geckoEmbedder);
      }
    });

    test('selects the per-tier embedder when the matrix maps them', () {
      const a = EmbedderModel(
        id: 'a',
        modelUrl: 'https://example.com/a',
        tokenizerUrl: 'https://example.com/a.tok',
        dimension: 768,
        approxDownloadMb: 1,
      );
      const b = EmbedderModel(
        id: 'b',
        modelUrl: 'https://example.com/b',
        tokenizerUrl: 'https://example.com/b.tok',
        dimension: 384,
        approxDownloadMb: 2,
      );
      const matrix = ModelCapabilityMatrix(
        embedders: {DeviceTier.low: a, DeviceTier.high: b},
      );

      expect(matrix.embedderFor(DeviceTier.low), a);
      expect(matrix.embedderFor(DeviceTier.high), b);
      // Unmapped tier falls back to the universal floor.
      expect(matrix.embedderFor(DeviceTier.mid), geckoEmbedder);
    });
  });
}
