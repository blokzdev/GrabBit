import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/generation_model.dart';
import 'package:grabbit/core/ai/model_capability_matrix.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/ai/transcription_model.dart';
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

  group('ModelCapabilityMatrix.eligibleEmbedders (P12c-3)', () {
    const matrix = ModelCapabilityMatrix();

    test('low tier offers only Gecko', () {
      expect(matrix.eligibleEmbedders(DeviceTier.low), [geckoEmbedder]);
    });

    test('mid/high tiers also offer the multilingual MiniLM', () {
      for (final tier in [DeviceTier.mid, DeviceTier.high]) {
        final eligible = matrix.eligibleEmbedders(tier);
        expect(eligible, contains(geckoEmbedder));
        expect(eligible, contains(paraphraseMultilingualMiniLmL12V2));
      }
    });

    test('the default is still Gecko at every tier (opt-in, never forced)', () {
      for (final tier in DeviceTier.values) {
        expect(matrix.embedderFor(tier), geckoEmbedder);
      }
    });
  });

  group('embedderById (P12c-3)', () {
    test('resolves the known catalog ids', () {
      expect(embedderById(geckoEmbedder.id), geckoEmbedder);
      expect(
        embedderById(paraphraseMultilingualMiniLmL12V2.id),
        paraphraseMultilingualMiniLmL12V2,
      );
    });

    test('returns null for an unknown id', () {
      expect(embedderById('nope'), isNull);
    });

    test('allEmbedders contains both shipped models', () {
      expect(allEmbedders, contains(geckoEmbedder));
      expect(allEmbedders, contains(paraphraseMultilingualMiniLmL12V2));
    });
  });

  group('ModelCapabilityMatrix generation row (P12d)', () {
    const matrix = ModelCapabilityMatrix();

    test('low tier offers no generation models (gated off)', () {
      expect(matrix.eligibleGenerationModels(DeviceTier.low), isEmpty);
      expect(matrix.recommendedGenerationModel(DeviceTier.low), isNull);
    });

    test('mid tier offers the small + balanced rungs', () {
      final mid = matrix.eligibleGenerationModels(DeviceTier.mid);
      expect(mid, contains(smolLm2_135mInstruct));
      expect(mid, contains(qwen3_0_6b));
    });

    test('high tier reaches the flagship rung', () {
      final high = matrix.eligibleGenerationModels(DeviceTier.high);
      expect(high, contains(gemma4E2b));
      expect(high, contains(qwen2_5_1_5b));
    });

    test('the recommendation is the balanced model on capable tiers', () {
      for (final tier in [DeviceTier.mid, DeviceTier.high]) {
        final rec = matrix.recommendedGenerationModel(tier);
        expect(rec, qwen3_0_6b);
        expect(matrix.eligibleGenerationModels(tier), contains(rec));
      }
    });
  });

  group('ModelCapabilityMatrix transcription row (P12e)', () {
    const matrix = ModelCapabilityMatrix();

    test('every tier offers at least one model (never gated off)', () {
      // Unlike generation (low = empty), transcription is never fully gated off.
      for (final tier in DeviceTier.values) {
        expect(matrix.eligibleTranscriptionModels(tier), isNotEmpty);
      }
    });

    test('low tier offers only tiny', () {
      expect(matrix.eligibleTranscriptionModels(DeviceTier.low), [whisperTiny]);
    });

    test('mid tier adds the base rung', () {
      final mid = matrix.eligibleTranscriptionModels(DeviceTier.mid);
      expect(mid, contains(whisperTiny));
      expect(mid, contains(whisperBase));
    });

    test('high tier reaches small + the flagship turbo', () {
      final high = matrix.eligibleTranscriptionModels(DeviceTier.high);
      expect(high, contains(whisperBase));
      expect(high, contains(whisperSmall));
      expect(high, contains(whisperLargeV3Turbo));
    });

    test(
      'the recommendation is tier-eligible (tiny on low, base on mid/high)',
      () {
        expect(
          matrix.recommendedTranscriptionModel(DeviceTier.low),
          whisperTiny,
        );
        for (final tier in DeviceTier.values) {
          final rec = matrix.recommendedTranscriptionModel(tier);
          expect(matrix.eligibleTranscriptionModels(tier), contains(rec));
        }
        for (final tier in [DeviceTier.mid, DeviceTier.high]) {
          expect(matrix.recommendedTranscriptionModel(tier), whisperBase);
        }
      },
    );
  });
}
