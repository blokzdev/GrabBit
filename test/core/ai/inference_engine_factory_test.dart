import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/inference_engine_factory.dart';
import 'package:grabbit/core/ai/model_catalog.dart';

void main() {
  group('inferenceEngineFor', () {
    test('propagates the selected model (id + dimension)', () {
      final engine = inferenceEngineFor(geckoEmbedder);
      expect(engine.model.id, geckoEmbedder.id);
      expect(engine.dimension, geckoEmbedder.dimension);
    });

    test('routes a custom model through too', () {
      const other = EmbedderModel(
        id: 'mini',
        modelUrl: 'https://example.com/m.tflite',
        tokenizerUrl: 'https://example.com/t.model',
        dimension: 384,
        approxDownloadMb: 50,
      );
      final engine = inferenceEngineFor(other);
      expect(engine.model.id, 'mini');
      expect(engine.dimension, 384);
    });

    test('is unavailable on a non-Android test host (graceful fallback)', () {
      // CI/desktop hosts have no flutter_gemma runtime → Unavailable, never crash.
      expect(inferenceEngineFor(geckoEmbedder).isAvailable, isFalse);
    });
  });
}
