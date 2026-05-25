import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/app.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';

DownloadTask _task(String status) => DownloadTask(
  id: 't1',
  url: 'u',
  requestJson: '{}',
  status: status,
  progress: 0,
  retries: 0,
  createdAt: DateTime.utc(2026),
  orderIndex: 0,
);

Future<void> _pumpApp(
  WidgetTester tester, {
  List<DownloadTask> tasks = const [],
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        filteredLibraryProvider.overrideWith((ref) => Stream.value(const [])),
        // Stub the streams the Dashboard landing aggregates; the real drift
        // .watch() leaves a pending timer on disposal that fails the test.
        libraryItemsProvider.overrideWith((ref) => Stream.value(<MediaItem>[])),
        queueTasksProvider.overrideWith((ref) => Stream.value(tasks)),
        collectionsProvider.overrideWith((ref) => Stream.value(<Collection>[])),
      ],
      child: const GrabBitApp(),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the Queue nav destination shows a running dot while running', (
    tester,
  ) async {
    await _pumpApp(tester, tasks: [_task(TaskStatus.running)]);
    expect(find.byKey(const Key('queueRunningDot')), findsOneWidget);
  });

  testWidgets('no running dot when nothing is running', (tester) async {
    await _pumpApp(tester, tasks: [_task(TaskStatus.queued)]);
    expect(find.byKey(const Key('queueRunningDot')), findsNothing);
  });
}
