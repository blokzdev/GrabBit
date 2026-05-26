import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/ai/unavailable_inference_engine.dart';

void main() {
  group('embeddingGemmaEmbedder catalog', () {
    test('pins a 256-d (Matryoshka) https model + tokenizer', () {
      expect(embeddingGemmaEmbedder.dimension, 256);
      expect(embeddingGemmaEmbedder.id, 'embeddinggemma_300m_seq256');
      expect(embeddingGemmaEmbedder.modelUrl, startsWith('https://'));
      expect(embeddingGemmaEmbedder.tokenizerUrl, startsWith('https://'));
      expect(embeddingGemmaEmbedder.approxDownloadMb, greaterThan(0));
    });
  });

  group('UnavailableInferenceEngine', () {
    const engine = UnavailableInferenceEngine();

    test('is never available and reports the pinned dimension', () {
      expect(engine.isAvailable, isFalse);
      expect(engine.dimension, embeddingGemmaEmbedder.dimension);
      expect(engine.model, embeddingGemmaEmbedder);
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
