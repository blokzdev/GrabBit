import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:grabbit/features/queue/data/foreground_service.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';
import 'package:grabbit/features/queue/data/queued_download.dart';
import 'package:grabbit/features/queue/presentation/queue_screen.dart';

class _IdleEngine implements DownloadEngine {
  @override
  Stream<DownloadProgress> download(DownloadRequest request) =>
      const Stream.empty();
  @override
  Future<void> cancel(String id) async {}
  @override
  Future<MediaInfo> probe(String url) async =>
      const MediaInfo(title: '', formats: []);
  @override
  Future<PlaylistInfo> expand(String url) async =>
      const PlaylistInfo(entries: []);
  @override
  Future<EngineVersion> version() async =>
      const EngineVersion(ytDlp: '1', ffmpeg: '1');
  @override
  Future<void> update() async {}
}

class _NoopService implements ForegroundService {
  @override
  set onStop(void Function() callback) {}
  @override
  Future<void> start(
    String text, {
    int progress = 0,
    bool indeterminate = true,
  }) async {}
  @override
  Future<void> update(
    String text, {
    int progress = 0,
    bool indeterminate = false,
  }) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<bool> isUnmetered() async => true;
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seedDone(String id, {String? requestJson, String url = 'u'}) =>
      db
          .into(db.downloadTasks)
          .insert(
            DownloadTasksCompanion.insert(
              id: id,
              url: url,
              requestJson: requestJson ?? '{}',
              status: TaskStatus.done,
              createdAt: DateTime.now(),
            ),
          );

  // Render the seeded rows via a synchronous stream so `.when` resolves
  // straight to data (no animating loading spinner to defeat pumpAndSettle).
  // The controller still builds against the in-memory DB for its actions.
  Future<void> pumpQueue(WidgetTester tester) async {
    final rows = await db.select(db.downloadTasks).get();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          downloadEngineProvider.overrideWithValue(_IdleEngine()),
          foregroundServiceProvider.overrideWithValue(_NoopService()),
          queueTasksProvider.overrideWith((ref) => Stream.value(rows)),
        ],
        child: const MaterialApp(home: QueueScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the media title from the persisted request', (
    tester,
  ) async {
    final json = jsonEncode(
      const QueuedDownload(
        request: DownloadRequest(
          taskId: 't1',
          url: 'https://example.com/v',
          outputDir: '/tmp',
          filenameTemplate: '%(title)s.%(ext)s',
        ),
        title: 'My Great Video',
      ).toJson(),
    );
    await seedDone('t1', requestJson: json, url: 'https://example.com/v');

    await pumpQueue(tester);

    expect(find.text('My Great Video'), findsOneWidget);
    expect(find.text('https://example.com/v'), findsNothing);
  });

  testWidgets('falls back to the URL when the request has no title', (
    tester,
  ) async {
    await seedDone('t1', url: 'https://example.com/legacy');

    await pumpQueue(tester);

    expect(find.text('https://example.com/legacy'), findsOneWidget);
  });

  testWidgets('shows an empty state when the queue has no tasks', (
    tester,
  ) async {
    await pumpQueue(tester);
    expect(find.text('No downloads in the queue'), findsOneWidget);
  });

  testWidgets('removal is gated by a confirmation dialog', (tester) async {
    await seedDone('t1', url: 'https://example.com/v');

    await pumpQueue(tester);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Remove from queue?'), findsOneWidget);

    // Declining keeps the task.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await QueueRepository(db).byId('t1'), isNotNull);
  });
}
