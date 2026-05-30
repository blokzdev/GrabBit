import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/ai/unavailable_embedder_engine.dart';

void main() {
  group('geckoEmbedder catalog', () {
    test('pins the 256-token, 768-d, ungated https model + tokenizer', () {
      expect(geckoEmbedder.dimension, 768);
      expect(geckoEmbedder.id, 'Gecko_256_quant');
      expect(geckoEmbedder.modelUrl, startsWith('https://'));
      expect(geckoEmbedder.modelUrl, contains('Gecko_256_quant.tflite'));
      expect(geckoEmbedder.tokenizerUrl, startsWith('https://'));
      expect(geckoEmbedder.approxDownloadMb, greaterThan(0));
    });

    test('runs on the flutter_gemma runtime and is the default (P10g-2)', () {
      expect(geckoEmbedder.runtime, EmbedderRuntime.flutterGemma);
      expect(defaultEmbedder, geckoEmbedder);
    });

    test('carries no app-managed files — flutter_gemma manages them (P12b)', () {
      // The plugin fetches/verifies Gecko opaquely, so no SHA-256'd ModelFiles.
      expect(geckoEmbedder.files, isEmpty);
    });
  });

  group('UnavailableEmbedderEngine', () {
    const engine = UnavailableEmbedderEngine();

    test('is never available and reports the pinned dimension', () {
      expect(engine.isAvailable, isFalse);
      expect(engine.dimension, geckoEmbedder.dimension);
      expect(engine.model, geckoEmbedder);
    });

    test('reflects the model it is given (P10g-2)', () {
      const other = EmbedderModel(
        id: 'other',
        modelUrl: 'https://example.com/m.tflite',
        tokenizerUrl: 'https://example.com/t.model',
        dimension: 384,
        approxDownloadMb: 50,
      );
      const e = UnavailableEmbedderEngine(other);
      expect(e.model, other);
      expect(e.dimension, 384);
    });

    test('ensureReady stays false without throwing', () async {
      expect(await engine.ensureReady(), isFalse);
    });

    test('embed throws unavailable', () async {
      await expectLater(
        engine.embed('hello'),
        throwsA(
          isA<InferenceException>().having(
            (e) => e.code,
            'code',
            InferenceErrorCode.unavailable,
          ),
        ),
      );
    });

    test('embedBatch throws unavailable', () async {
      await expectLater(
        engine.embedBatch(const ['a', 'b']),
        throwsA(
          isA<InferenceException>().having(
            (e) => e.code,
            'code',
            InferenceErrorCode.unavailable,
          ),
        ),
      );
    });

    test('downloadModel throws unavailable', () async {
      await expectLater(
        engine.downloadModel(),
        throwsA(
          isA<InferenceException>().having(
            (e) => e.code,
            'code',
            InferenceErrorCode.unavailable,
          ),
        ),
      );
    });

    test('close is a no-op', () async {
      await expectLater(engine.close(), completes);
    });
  });
}
