import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:grabbit/features/downloader/presentation/downloader_controller.dart';
import 'package:grabbit/features/downloader/presentation/selection_controller.dart';

/// Engine returning a configurable number of expanded entries, and a fixed
/// single-item probe result.
class _FakeEngine implements DownloadEngine {
  _FakeEngine(this.entryCount);
  final int entryCount;

  @override
  Future<PlaylistInfo> expand(String url) async => PlaylistInfo(
    entries: [
      for (var i = 0; i < entryCount; i++)
        MediaEntry(url: '$url#$i', title: 'Entry $i'),
    ],
  );

  @override
  Future<MediaInfo> probe(String url) async =>
      const MediaInfo(title: 'Single clip', formats: []);

  @override
  Stream<DownloadProgress> download(DownloadRequest request) =>
      const Stream.empty();

  @override
  Future<void> cancel(String taskId) async {}

  @override
  Future<EngineVersion> version() async =>
      const EngineVersion(ytDlp: '1', ffmpeg: '1');

  @override
  Future<void> update() async {}
}

void main() {
  ProviderContainer makeContainer(int entryCount) => ProviderContainer(
    overrides: [
      downloadEngineProvider.overrideWithValue(_FakeEngine(entryCount)),
    ],
  );

  test(
    'checkSingle routes a multi-entry URL to the selection picker',
    () async {
      final container = makeContainer(3);
      addTearDown(container.dispose);

      final isMulti = await container
          .read(downloaderControllerProvider.notifier)
          .checkSingle('https://example.com/playlist');

      expect(isMulti, isTrue);
      // Sources were handed to the selection controller, all selected.
      final selection = container.read(selectionControllerProvider);
      expect(selection.totalCount, 3);
      expect(selection.selected, hasLength(3));
      // The downloader form is reset (no lingering preview).
      expect(
        container.read(downloaderControllerProvider).phase,
        DownloaderPhase.idle,
      );
    },
  );

  test('checkSingle falls through to probe for a single entry', () async {
    final container = makeContainer(1);
    addTearDown(container.dispose);

    final isMulti = await container
        .read(downloaderControllerProvider.notifier)
        .checkSingle('https://example.com/video');

    expect(isMulti, isFalse);
    final state = container.read(downloaderControllerProvider);
    expect(state.phase, DownloaderPhase.ready);
    expect(state.info?.title, 'Single clip');
  });
}
