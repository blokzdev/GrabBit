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

    test('onnx runtime is stubbed to unavailable until P12c', () {
      const onnx = EmbedderModel(
        id: 'mini-multilingual',
        modelUrl: 'https://example.com/model.onnx',
        tokenizerUrl: 'https://example.com/tokenizer.json',
        dimension: 384,
        approxDownloadMb: 120,
        runtime: EmbedderRuntime.onnx,
      );
      final engine = inferenceEngineFor(onnx);
      expect(engine.isAvailable, isFalse);
      expect(engine.model.id, 'mini-multilingual');
      expect(engine.dimension, 384);
    });
  });
}
