import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/transcription_engine_factory.dart';
import 'package:grabbit/core/ai/transcription_model.dart';

void main() {
  group('transcriptionEngineFor', () {
    test('reports the selected model', () {
      final engine = transcriptionEngineFor(whisperBase);
      expect(engine.model, whisperBase);
    });

    test('is unavailable without a downloads service (graceful fallback)', () {
      // No ModelDownloadService → can't manage the model file → Unavailable.
      expect(transcriptionEngineFor(whisperTiny).isAvailable, isFalse);
    });

    test('is unavailable on a non-Android test host', () {
      // CI/desktop has no whisper.cpp native lib → Unavailable, never crashes.
      // (downloads omitted here, which also routes to Unavailable.)
      final engine = transcriptionEngineFor(whisperLargeV3Turbo);
      expect(engine.isAvailable, isFalse);
      expect(engine.model, whisperLargeV3Turbo);
    });
  });
}
