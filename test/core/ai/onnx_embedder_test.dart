import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/inference_engine_factory.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/ai/onnx_embedder_inference_engine.dart';

void main() {
  group('meanPool', () {
    test('averages only the attended (mask==1) token rows', () {
      final pooled = meanPool(
        [
          [1.0, 2.0],
          [3.0, 4.0],
          [5.0, 6.0], // padding — ignored
        ],
        [1, 1, 0],
      );
      expect(pooled, [2.0, 3.0]);
    });

    test('an all-padding input pools to a zero vector', () {
      expect(
        meanPool(
          [
            [1.0, 2.0],
            [3.0, 4.0],
          ],
          [0, 0],
        ),
        [0.0, 0.0],
      );
    });
  });

  group('l2Normalize', () {
    test('scales to unit length', () {
      expect(l2Normalize([3.0, 4.0]), [0.6, 0.8]);
    });

    test('leaves a zero vector unchanged (no divide-by-zero)', () {
      expect(l2Normalize([0.0, 0.0]), [0.0, 0.0]);
    });
  });

  group('paraphraseMultilingualMiniLmL12V2 catalog entry', () {
    const model = paraphraseMultilingualMiniLmL12V2;

    test('is the onnx multilingual model (384-d, 128-token window)', () {
      expect(model.runtime, EmbedderRuntime.onnx);
      expect(model.dimension, 384);
      expect(model.maxTokens, 128);
      expect(model.approxDownloadMb, greaterThan(0));
    });

    test('declares two SHA-256-pinned files (model.onnx + tokenizer.json)', () {
      expect(model.files.map((f) => f.filename), [
        'model.onnx',
        'tokenizer.json',
      ]);
      for (final f in model.files) {
        expect(f.url, startsWith('https://'));
        expect(f.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(f.sizeBytes, greaterThan(0));
      }
    });
  });

  test('factory falls back to unavailable for onnx on a non-Android host', () {
    // CI/desktop have no onnxruntime plugin → graceful fallback, never a crash;
    // the engine still reports the selected model + dimension.
    final engine = inferenceEngineFor(paraphraseMultilingualMiniLmL12V2);
    expect(engine.isAvailable, isFalse);
    expect(engine.model.id, paraphraseMultilingualMiniLmL12V2.id);
    expect(engine.dimension, 384);
  });
}
