import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/transcription_model.dart';

void main() {
  group('transcriptionModelById', () {
    test('resolves every shipped id', () {
      for (final m in allTranscriptionModels) {
        expect(transcriptionModelById(m.id), m);
      }
    });

    test('returns null for an unknown id', () {
      expect(transcriptionModelById('nope'), isNull);
    });
  });

  group('catalog posture + shape', () {
    test('every model is MIT (off-store redistribution guard)', () {
      for (final m in allTranscriptionModels) {
        expect(
          m.license.toLowerCase(),
          anyOf(contains('mit'), contains('apache')),
          reason: '${m.id} must be MIT/Apache for off-store distribution',
        );
      }
    });

    test('every model has a display name, blurb, class, and ggml file', () {
      for (final m in allTranscriptionModels) {
        expect(m.displayName, isNotEmpty);
        expect(m.blurb, isNotEmpty);
        expect(TranscriptionModelClass.values, contains(m.modelClass));
        expect(m.approxDownloadMb, greaterThan(0));
        expect(m.file.filename, endsWith('.bin'));
      }
    });

    test('every model pins a real https ggml URL + sha256 + matching size', () {
      for (final m in allTranscriptionModels) {
        expect(m.file.url, startsWith('https://huggingface.co/'));
        expect(m.file.url, endsWith('.bin'));
        // SHA-256 is 64 lowercase hex chars (HEAD-verified LFS oid).
        expect(m.file.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(m.file.sizeBytes, greaterThan(0));
        // approxDownloadMb is the decimal-MB rounding of the real byte size.
        expect(m.approxDownloadMb, (m.file.sizeBytes / 1e6).round());
      }
    });

    test('exactly one model per size band (tiny/base/small/turbo)', () {
      for (final band in TranscriptionModelClass.values) {
        expect(
          allTranscriptionModels.where((m) => m.modelClass == band),
          hasLength(1),
          reason: 'one model per $band band',
        );
      }
    });
  });
}
