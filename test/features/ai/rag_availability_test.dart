import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/ai/data/rag_availability.dart';

void main() {
  group('ragAvailability (P13d-1)', () {
    test('no embedder or no graph → unavailable', () {
      expect(
        ragAvailability(
          generationEligible: true,
          embedderReady: false,
          graphAvailable: true,
        ),
        RagAvailability.unavailable,
      );
      expect(
        ragAvailability(
          generationEligible: true,
          embedderReady: true,
          graphAvailable: false,
        ),
        RagAvailability.unavailable,
      );
    });

    test('retrieval works but no generation model → retrievalOnly', () {
      expect(
        ragAvailability(
          generationEligible: false,
          embedderReady: true,
          graphAvailable: true,
        ),
        RagAvailability.retrievalOnly,
      );
    });

    test('all three → full', () {
      expect(
        ragAvailability(
          generationEligible: true,
          embedderReady: true,
          graphAvailable: true,
        ),
        RagAvailability.full,
      );
    });
  });
}
