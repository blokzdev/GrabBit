import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:grabbit/features/settings/presentation/engine_update_controller.dart';

class _FakeEngine implements DownloadEngine {
  _FakeEngine();
  String ytDlp = '2026.05.01';
  int updateCalls = 0;

  @override
  Future<EngineVersion> version() async =>
      EngineVersion(ytDlp: ytDlp, ffmpeg: 'bundled');

  @override
  Future<void> update() async {
    updateCalls++;
    ytDlp = '2026.05.20';
  }

  @override
  Future<MediaInfo> probe(String url) async =>
      const MediaInfo(title: '', formats: []);
  @override
  Future<PlaylistInfo> expand(String url) async =>
      const PlaylistInfo(entries: []);
  @override
  Stream<DownloadProgress> download(DownloadRequest request) =>
      const Stream.empty();
  @override
  Future<void> cancel(String taskId) async {}
}

void main() {
  test('loads version, then runUpdate refreshes it', () async {
    final engine = _FakeEngine();
    final container = ProviderContainer(
      overrides: [downloadEngineProvider.overrideWithValue(engine)],
    );
    addTearDown(container.dispose);

    final loaded = await container.read(engineUpdateControllerProvider.future);
    expect(loaded.version, '2026.05.01');

    await container.read(engineUpdateControllerProvider.notifier).runUpdate();

    expect(engine.updateCalls, 1);
    final state = container.read(engineUpdateControllerProvider).asData?.value;
    expect(state?.version, '2026.05.20');
    expect(state?.message, isNotNull);
  });

  group('shouldAutoCheckEngine', () {
    final now = DateTime.utc(2026, 5, 21, 12);

    test('disabled → never checks', () {
      expect(
        shouldAutoCheckEngine(enabled: false, lastCheck: null, now: now),
        isFalse,
      );
    });

    test('enabled + never checked → checks', () {
      expect(
        shouldAutoCheckEngine(enabled: true, lastCheck: null, now: now),
        isTrue,
      );
    });

    test('respects the 24h interval', () {
      expect(
        shouldAutoCheckEngine(
          enabled: true,
          lastCheck: now.subtract(const Duration(hours: 23)),
          now: now,
        ),
        isFalse,
      );
      expect(
        shouldAutoCheckEngine(
          enabled: true,
          lastCheck: now.subtract(const Duration(hours: 25)),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
