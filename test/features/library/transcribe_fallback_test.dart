import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/library/presentation/transcribe_fallback.dart';

void main() {
  group('transcribeFallbackAction (P12e-3)', () {
    test('unsupported host → unavailable (today\'s dead-end)', () {
      expect(
        transcribeFallbackAction(
          supported: false,
          enabled: false,
          modelReady: false,
        ),
        TranscribeFallbackAction.unavailable,
      );
      // Even if somehow enabled/ready, an unsupported host can't run whisper.
      expect(
        transcribeFallbackAction(
          supported: false,
          enabled: true,
          modelReady: true,
        ),
        TranscribeFallbackAction.unavailable,
      );
    });

    test('supported + disabled → offer setup (enable + download)', () {
      expect(
        transcribeFallbackAction(
          supported: true,
          enabled: false,
          modelReady: false,
        ),
        TranscribeFallbackAction.offerSetup,
      );
    });

    test('supported + enabled + no model → offer download', () {
      expect(
        transcribeFallbackAction(
          supported: true,
          enabled: true,
          modelReady: false,
        ),
        TranscribeFallbackAction.offerDownload,
      );
    });

    test('supported + enabled + model ready → transcribe now', () {
      expect(
        transcribeFallbackAction(
          supported: true,
          enabled: true,
          modelReady: true,
        ),
        TranscribeFallbackAction.transcribeNow,
      );
    });
  });
}
