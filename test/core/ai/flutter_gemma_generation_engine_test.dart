import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/flutter_gemma_generation_engine.dart';
import 'package:grabbit/core/ai/generation_engine_factory.dart';
import 'package:grabbit/core/ai/generation_model.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/storage/disk_space_service.dart';

class _FakeDiskSpace implements DiskSpaceService {
  _FakeDiskSpace(this.freeBytes);
  final int freeBytes;
  @override
  Future<DiskSpace> query(String path) async =>
      (freeBytes: freeBytes, totalBytes: freeBytes);
}

void main() {
  group('modelTypeForId', () {
    test('maps every shipped catalog id to a ModelType', () {
      // Each shipped model's modelTypeId must resolve (catalog↔plugin contract).
      const expected = {
        'general': ModelType.general,
        'qwen3': ModelType.qwen3,
        'qwen': ModelType.qwen,
        'gemma4': ModelType.gemma4,
      };
      for (final m in allGenerationModels) {
        expect(
          modelTypeForId(m.modelTypeId),
          expected[m.modelTypeId],
          reason: '${m.id} → ${m.modelTypeId}',
        );
      }
    });

    test('throws on an unknown id (a catalog/plugin mismatch is a bug)', () {
      expect(() => modelTypeForId('nope'), throwsArgumentError);
    });
  });

  test('factory falls back to Unavailable off-Android (CI host)', () {
    // No flutter_gemma runtime on the CI host → graceful Unavailable, never a
    // crash; the engine still reports the selected model.
    final engine = generationEngineFor(qwen3_0_6b);
    expect(engine.isAvailable, isFalse);
    expect(engine.model, qwen3_0_6b);
  });

  test(
    'the storage guard rejects a too-large download before any plugin call',
    () {
      // Guard runs before _ensureInit(), so this never touches flutter_gemma.
      final engine = FlutterGemmaGenerationEngine(
        gemma4E2b, // ~2.5 GB
        diskSpace: _FakeDiskSpace(100 * 1024 * 1024), // only 100 MB free
        storageDirPath: () async => '/tmp',
      );
      expect(
        engine.downloadModel(),
        throwsA(
          isA<InferenceException>().having(
            (e) => e.code,
            'code',
            InferenceErrorCode.downloadFailed,
          ),
        ),
      );
    },
  );
}
