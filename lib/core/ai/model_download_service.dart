import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/model_file.dart';
import 'package:grabbit/core/storage/disk_space_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'model_download_service.g.dart';

/// A streamed byte source for [ModelDownloadService] — the seam that lets tests
/// feed good or corrupt bytes in-memory without touching the network.
abstract interface class ModelByteSource {
  /// Streams [url]'s bytes. [contentLength] is the server-advertised size when
  /// known, else null. Throws on transport failure.
  Future<({Stream<List<int>> bytes, int? contentLength})> fetch(String url);
}

/// Default [ModelByteSource]: a streamed GET via `dart:io` HttpClient (follows
/// redirects, e.g. a Hugging Face `resolve` URL → CDN). A non-200 response maps
/// to `InferenceErrorCode.downloadFailed`.
class HttpClientModelByteSource implements ModelByteSource {
  @override
  Future<({Stream<List<int>> bytes, int? contentLength})> fetch(
    String url,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        client.close(force: true);
        throw InferenceException(
          InferenceErrorCode.downloadFailed,
          'HTTP ${response.statusCode} fetching $url',
        );
      }
      final length = response.contentLength >= 0
          ? response.contentLength
          : null;
      return (bytes: _closeWhenDone(response, client), contentLength: length);
    } on InferenceException {
      rethrow;
    } catch (e) {
      client.close(force: true);
      throw InferenceException(
        InferenceErrorCode.downloadFailed,
        'Failed to fetch $url',
        cause: e,
      );
    }
  }

  Stream<List<int>> _closeWhenDone(
    HttpClientResponse response,
    HttpClient client,
  ) async* {
    try {
      yield* response;
    } finally {
      client.close();
    }
  }
}

/// Catalog-driven, on-demand downloader for **file-based** models (P12b). Fetches
/// each [ModelFile] with progress, verifies its SHA-256, and caches it under
/// app-private `<appSupport>/models/<modelId>/`. Idempotent (a present,
/// hash-matching file is never refetched), atomic (verify-then-rename), and
/// space-guarded. The flutter_gemma embedder does **not** use this — its files
/// are plugin-managed (see `flutter_gemma_embedder_engine.dart`).
class ModelDownloadService {
  ModelDownloadService({
    required this.byteSource,
    required this.diskSpace,
    required this.modelsRoot,
  });

  final ModelByteSource byteSource;
  final DiskSpaceService diskSpace;
  final Future<Directory> Function() modelsRoot;

  /// Extra free space required beyond the download itself.
  static const _headroomBytes = 32 * 1024 * 1024;

  /// In-flight downloads keyed by modelId, so concurrent callers share one run
  /// instead of racing on the same `.part` file.
  final Map<String, Future<Map<String, String>>> _inFlight = {};

  /// Ensures every [files] asset for [modelId] is downloaded, SHA-256-verified,
  /// and cached. Reports cumulative progress 0..1 (weighted by
  /// [ModelFile.sizeBytes]). Returns `{filename: absolutePath}`. Throws
  /// [InferenceException] with `downloadFailed` on transport error, hash
  /// mismatch, or insufficient free space.
  Future<Map<String, String>> ensureDownloaded(
    String modelId,
    List<ModelFile> files, {
    void Function(double progress)? onProgress,
  }) {
    if (files.isEmpty) {
      onProgress?.call(1);
      return Future.value(const {});
    }
    final existing = _inFlight[modelId];
    if (existing != null) return existing;
    // Block body (returns void): `Map.remove` returns the stored future, and
    // an arrow callback would make `whenComplete` await that future — i.e. the
    // run awaiting itself — a deadlock.
    final run = _run(modelId, files, onProgress).whenComplete(() {
      _inFlight.remove(modelId);
    });
    _inFlight[modelId] = run;
    return run;
  }

  Future<Map<String, String>> _run(
    String modelId,
    List<ModelFile> files,
    void Function(double progress)? onProgress,
  ) async {
    try {
      final root = await modelsRoot();
      final dir = Directory('${root.path}/$modelId');
      await dir.create(recursive: true);

      // Partition into already-cached (present + hash-matching) vs. pending.
      final paths = <String, String>{};
      final pending = <ModelFile>[];
      for (final file in files) {
        final dest = File('${dir.path}/${file.filename}');
        if (await dest.exists() && await _hashOf(dest) == file.sha256) {
          paths[file.filename] = dest.path;
        } else {
          pending.add(file);
        }
      }
      if (pending.isEmpty) {
        onProgress?.call(1);
        return paths;
      }

      // Free-space guard before fetching anything.
      final totalBytes = pending.fold<int>(0, (sum, f) => sum + f.sizeBytes);
      final space = await diskSpace.query(dir.path);
      if (space.freeBytes < totalBytes + _headroomBytes) {
        throw InferenceException(
          InferenceErrorCode.downloadFailed,
          'Insufficient free storage to download the model '
          '(need ~${(totalBytes + _headroomBytes) ~/ (1024 * 1024)} MB).',
        );
      }

      var doneBytes = 0;
      for (final file in pending) {
        paths[file.filename] = await _downloadOne(
          dir,
          file,
          onChunk: (received) {
            final progress = totalBytes == 0
                ? 1.0
                : (doneBytes + received) / totalBytes;
            onProgress?.call(progress.clamp(0.0, 1.0).toDouble());
          },
        );
        doneBytes += file.sizeBytes;
      }
      onProgress?.call(1);
      return paths;
    } on InferenceException {
      rethrow;
    } catch (e) {
      throw InferenceException(
        InferenceErrorCode.downloadFailed,
        'Failed to download model "$modelId"',
        cause: e,
      );
    }
  }

  Future<String> _downloadOne(
    Directory dir,
    ModelFile file, {
    required void Function(int receivedBytes) onChunk,
  }) async {
    final dest = File('${dir.path}/${file.filename}');
    // `.part` shares the destination dir so the final rename is atomic (same
    // volume); openWrite truncates any leftover from a crashed prior run.
    final part = File('${dest.path}.part');
    final source = await byteSource.fetch(file.url);
    final sink = part.openWrite();
    final digestSink = _DigestSink();
    final hashInput = sha256.startChunkedConversion(digestSink);
    var received = 0;
    try {
      await for (final chunk in source.bytes) {
        sink.add(chunk);
        hashInput.add(chunk);
        received += chunk.length;
        onChunk(received);
      }
      await sink.flush();
      await sink.close();
      hashInput.close();
    } catch (_) {
      await sink.close().catchError((_) {});
      if (await part.exists()) await part.delete();
      rethrow;
    }

    if (digestSink.value.toString() != file.sha256) {
      if (await part.exists()) await part.delete();
      throw InferenceException(
        InferenceErrorCode.downloadFailed,
        'SHA-256 mismatch for ${file.filename}',
      );
    }
    await part.rename(dest.path);
    return dest.path;
  }

  /// True iff every [files] asset is present on disk with a matching SHA-256.
  Future<bool> isInstalled(String modelId, List<ModelFile> files) async {
    final root = await modelsRoot();
    final dir = Directory('${root.path}/$modelId');
    for (final file in files) {
      final dest = File('${dir.path}/${file.filename}');
      if (!await dest.exists() || await _hashOf(dest) != file.sha256) {
        return false;
      }
    }
    return true;
  }

  /// Resolves `<root>/<modelId>/<filename>` (no I/O).
  Future<String> pathFor(String modelId, String filename) async {
    final root = await modelsRoot();
    return '${root.path}/$modelId/$filename';
  }

  /// The ids of models with cached files on disk — a model dir that exists and
  /// holds at least one file. Existence-only (no hashing): cheap, for UI state;
  /// [isInstalled] is the authoritative hash-checked gate used before inference.
  Future<Set<String>> installedModelIds() async {
    final root = await modelsRoot();
    if (!await root.exists()) return const <String>{};
    final ids = <String>{};
    await for (final entry in root.list()) {
      if (entry is Directory && await entry.list().any((e) => e is File)) {
        ids.add(entry.path.split('/').last);
      }
    }
    return ids;
  }

  /// Removes [modelId]'s cached files to free space. No-op if absent. The
  /// model stays in the catalog and is re-downloadable on demand.
  Future<void> delete(String modelId) async {
    final root = await modelsRoot();
    final dir = Directory('${root.path}/$modelId');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<String> _hashOf(File file) async {
    final digestSink = _DigestSink();
    final input = sha256.startChunkedConversion(digestSink);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    return digestSink.value.toString();
  }
}

/// Captures the single [Digest] that `sha256.startChunkedConversion` emits on
/// close — lets us fold the hash over a stream without buffering the file.
class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

@Riverpod(keepAlive: true)
ModelDownloadService modelDownloadService(Ref ref) => ModelDownloadService(
  byteSource: HttpClientModelByteSource(),
  diskSpace: ref.watch(diskSpaceServiceProvider),
  modelsRoot: () async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/models');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  },
);
