import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/library/presentation/extract_things.dart';

void main() {
  group('extractThingsAction', () {
    test('ineligible → unavailable (regardless of other flags)', () {
      expect(
        extractThingsAction(eligible: false, enabled: true, modelReady: true),
        ExtractThingsAction.unavailable,
      );
    });

    test('eligible but not enabled → offerSetup', () {
      expect(
        extractThingsAction(eligible: true, enabled: false, modelReady: false),
        ExtractThingsAction.offerSetup,
      );
    });

    test('enabled but model not ready → offerDownload', () {
      expect(
        extractThingsAction(eligible: true, enabled: true, modelReady: false),
        ExtractThingsAction.offerDownload,
      );
    });

    test('eligible + enabled + ready → extractNow', () {
      expect(
        extractThingsAction(eligible: true, enabled: true, modelReady: true),
        ExtractThingsAction.extractNow,
      );
    });
  });

  group('autoExtractDecision', () {
    test('not eligible → skip (no FC model active; no nudge)', () {
      expect(
        autoExtractDecision(eligible: false, modelReady: false),
        AutoExtractDecision.skip,
      );
      expect(
        autoExtractDecision(eligible: false, modelReady: true),
        AutoExtractDecision.skip,
      );
    });

    test('eligible but model not downloaded → needsModel', () {
      expect(
        autoExtractDecision(eligible: true, modelReady: false),
        AutoExtractDecision.needsModel,
      );
    });

    test('eligible + ready → extract', () {
      expect(
        autoExtractDecision(eligible: true, modelReady: true),
        AutoExtractDecision.extract,
      );
    });
  });
}
