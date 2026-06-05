import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/model_download_service.dart';
import 'package:grabbit/core/ai/model_file.dart';
import 'package:grabbit/core/storage/disk_space_service.dart';

/// Emits the stubbed chunks for each URL; throws (→ downloadFailed) for unknown
/// URLs. Counts fetches so tests can prove a cached file is never refetched.
class _FakeByteSource implements ModelByteSource {
  _FakeByteSource(this._responses);
  final Map<String, List<List<int>>> _responses;
  int fetchCount = 0;

  @override
  Future<({Stream<List<int>> bytes, int? contentLength})> fetch(
    String url,
  ) async {
    fetchCount++;
    final chunks = _responses[url];
    if (chunks == null) {
      throw const InferenceException(
        InferenceErrorCode.downloadFailed,
        'no stub',
      );
    }
    final total = chunks.fold<int>(0, (s, c) => s + c.length);
    return (bytes: Stream.fromIterable(chunks), contentLength: total);
  }
}

class _LowSpaceDiskSpaceService implements DiskSpaceService {
  _LowSpaceDiskSpaceService(this.freeBytes);
  final int freeBytes;
  @override
  Future<DiskSpace> query(String path) async =>
      (freeBytes: freeBytes, totalBytes: freeBytes);
}

const _zeroHash =
    '0000000000000000000000000000000000000000000000000000000000000000';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('model_dl_test');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  ModelDownloadService service({
    ModelByteSource? source,
    DiskSpaceService? disk,
  }) => ModelDownloadService(
    byteSource: source ?? _FakeByteSource({}),
    diskSpace: disk ?? NoopDiskSpaceService(),
    modelsRoot: () async => root,
  );

  ModelFile fileFor(List<int> bytes, {String filename = 'model.bin'}) =>
      ModelFile(
        url: 'https://example.com/$filename',
        sha256: sha256.convert(bytes).toString(),
        sizeBytes: bytes.length,
        filename: filename,
      );

  void expectMonotonic(List<double> values) {
    for (var i = 1; i < values.length; i++) {
      expect(values[i] >= values[i - 1], isTrue, reason: 'progress regressed');
    }
  }

  test('downloads, verifies and caches a catalog entry', () async {
    final bytes = utf8.encode('hello model weights' * 4);
    final file = fileFor(bytes);
    final svc = service(
      source: _FakeByteSource({
        file.url: [bytes],
      }),
    );
    final progress = <double>[];

    final paths = await svc.ensureDownloaded('m1', [
      file,
    ], onProgress: progress.add);

    final dest = File('${root.path}/m1/model.bin');
    expect(await dest.exists(), isTrue);
    expect(await dest.readAsBytes(), bytes);
    expect(paths['model.bin'], dest.path);
    expect(progress.last, 1.0);
    expectMonotonic(progress);
    expect(await File('${dest.path}.part').exists(), isFalse);
  });

  test('streamed digest matches across multiple chunks', () async {
    final bytes = List<int>.generate(5000, (i) => i % 256);
    final file = fileFor(bytes);
    // Three uneven chunks exercise the incremental hash fold.
    final chunks = [
      bytes.sublist(0, 1000),
      bytes.sublist(1000, 4096),
      bytes.sublist(4096),
    ];
    final svc = service(source: _FakeByteSource({file.url: chunks}));

    final paths = await svc.ensureDownloaded('m2', [file]);

    expect(await File(paths['model.bin']!).readAsBytes(), bytes);
  });

  test(
    'rejects a hash mismatch with downloadFailed and leaves nothing',
    () async {
      final bytes = utf8.encode('corrupt');
      final bad = ModelFile(
        url: 'https://example.com/model.bin',
        sha256: _zeroHash, // not the real digest
        sizeBytes: bytes.length,
        filename: 'model.bin',
      );
      final svc = service(
        source: _FakeByteSource({
          bad.url: [bytes],
        }),
      );

      await expectLater(
        svc.ensureDownloaded('m3', [bad]),
        throwsA(
          isA<InferenceException>().having(
            (e) => e.code,
            'code',
            InferenceErrorCode.downloadFailed,
          ),
        ),
      );
      expect(await File('${root.path}/m3/model.bin').exists(), isFalse);
      expect(await File('${root.path}/m3/model.bin.part').exists(), isFalse);
    },
  );

  test('maps a transport failure to downloadFailed', () async {
    final bytes = utf8.encode('x');
    final file = fileFor(bytes);
    final svc = service(source: _FakeByteSource({})); // no stub → fetch throws

    await expectLater(
      svc.ensureDownloaded('m4', [file]),
      throwsA(
        isA<InferenceException>().having(
          (e) => e.code,
          'code',
          InferenceErrorCode.downloadFailed,
        ),
      ),
    );
  });

  test(
    're-install is a no-op: a cached, hash-matching file is not refetched',
    () async {
      final bytes = utf8.encode('already here');
      final file = fileFor(bytes);
      await Directory('${root.path}/m5').create(recursive: true);
      await File('${root.path}/m5/model.bin').writeAsBytes(bytes);

      final source = _FakeByteSource({
        file.url: [bytes],
      });
      final svc = service(source: source);
      final paths = await svc.ensureDownloaded('m5', [file]);

      expect(source.fetchCount, 0);
      expect(paths['model.bin'], '${root.path}/m5/model.bin');
    },
  );

  test('free-space guard blocks before any fetch', () async {
    final bytes = List<int>.filled(1000, 7);
    final file = fileFor(bytes);
    final source = _FakeByteSource({
      file.url: [bytes],
    });
    final svc = service(source: source, disk: _LowSpaceDiskSpaceService(10));

    await expectLater(
      svc.ensureDownloaded('m6', [file]),
      throwsA(
        isA<InferenceException>().having(
          (e) => e.code,
          'code',
          InferenceErrorCode.downloadFailed,
        ),
      ),
    );
    expect(source.fetchCount, 0);
  });

  test('multi-file download reaches 1.0 once and is monotonic', () async {
    final big = List<int>.filled(8000, 1);
    final small = List<int>.filled(200, 2);
    final f1 = fileFor(big, filename: 'weights.bin');
    final f2 = fileFor(small, filename: 'tokenizer.json');
    final svc = service(
      source: _FakeByteSource({
        f1.url: [big],
        f2.url: [small],
      }),
    );
    final progress = <double>[];

    final paths = await svc.ensureDownloaded('m7', [
      f1,
      f2,
    ], onProgress: progress.add);

    expect(paths.keys, containsAll(['weights.bin', 'tokenizer.json']));
    expect(progress.last, 1.0);
    expect(progress.where((p) => p == 1.0).length, greaterThanOrEqualTo(1));
    expectMonotonic(progress);
  });

  test('empty files is a no-op (the flutter_gemma case)', () async {
    final svc = service();
    final progress = <double>[];
    final paths = await svc.ensureDownloaded(
      'gemma',
      [],
      onProgress: progress.add,
    );
    expect(paths, isEmpty);
    expect(progress, [1.0]);
  });

  test('isInstalled and pathFor reflect on-disk state', () async {
    final bytes = utf8.encode('weights');
    final file = fileFor(bytes);
    final svc = service(
      source: _FakeByteSource({
        file.url: [bytes],
      }),
    );

    expect(await svc.isInstalled('m8', [file]), isFalse);
    await svc.ensureDownloaded('m8', [file]);
    expect(await svc.isInstalled('m8', [file]), isTrue);
    expect(await svc.pathFor('m8', 'model.bin'), '${root.path}/m8/model.bin');
  });

  test('concurrent calls for the same model share one in-flight download', () {
    final bytes = utf8.encode('shared');
    final file = fileFor(bytes);
    final svc = service(
      source: _FakeByteSource({
        file.url: [bytes],
      }),
    );

    final a = svc.ensureDownloaded('m9', [file]);
    final b = svc.ensureDownloaded('m9', [file]);
    expect(identical(a, b), isTrue);
    return Future.wait([a, b]);
  });

  group('installedModelIds + delete (P13f-1)', () {
    test('lists model dirs that hold files; ignores empties', () async {
      final bytes = utf8.encode('weights');
      final file = fileFor(bytes);
      final svc = service(
        source: _FakeByteSource({
          file.url: [bytes],
        }),
      );
      await svc.ensureDownloaded('m1', [file]);
      // An empty dir (no files) must not count as installed.
      await Directory('${root.path}/empty').create(recursive: true);

      expect(await svc.installedModelIds(), {'m1'});
    });

    test('empty when nothing is downloaded', () async {
      expect(await service().installedModelIds(), isEmpty);
    });

    test('delete removes the cached model; no-op when absent', () async {
      final bytes = utf8.encode('weights');
      final file = fileFor(bytes);
      final svc = service(
        source: _FakeByteSource({
          file.url: [bytes],
        }),
      );
      await svc.ensureDownloaded('m1', [file]);
      expect(await svc.isInstalled('m1', [file]), isTrue);

      await svc.delete('m1');
      expect(await Directory('${root.path}/m1').exists(), isFalse);
      expect(await svc.isInstalled('m1', [file]), isFalse);
      expect(await svc.installedModelIds(), isEmpty);

      await svc.delete('ghost'); // absent → no throw
    });
  });
}
