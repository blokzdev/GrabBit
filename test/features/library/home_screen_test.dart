import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/data/folder_repository.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/explorer_view.dart';
import 'package:grabbit/features/library/presentation/home_screen.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/library_view.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';

DownloadTask _task(String status) => DownloadTask(
  id: 't1',
  url: 'u',
  requestJson: '{}',
  status: status,
  progress: 0,
  retries: 0,
  createdAt: DateTime.utc(2026),
);

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    List<DownloadTask> tasks = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          queueTasksProvider.overrideWith((ref) => Stream.value(tasks)),
          collectionsProvider.overrideWith(
            (ref) => Stream.value(<Collection>[]),
          ),
          filteredLibraryProvider.overrideWith(
            (ref) => Stream.value(<MediaItem>[]),
          ),
          subfoldersProvider.overrideWith((ref, _) => Stream.value(<Folder>[])),
          folderItemsProvider.overrideWith(
            (ref, _) => Stream.value(<MediaItem>[]),
          ),
          folderItemCountsProvider.overrideWith(
            (ref) => Stream.value(<int, int>{}),
          ),
          breadcrumbProvider.overrideWith((ref, _) async => <Folder>[]),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(); // deliver the Stream.value provider emissions
  }

  testWidgets('shows the brand wordmark', (tester) async {
    await pumpHome(tester);
    expect(find.text('GrabBit'), findsOneWidget);
  });

  testWidgets('toggles between Library and Explorer views', (tester) async {
    await pumpHome(tester);
    expect(find.byType(LibraryView), findsOneWidget);
    expect(find.byType(ExplorerView), findsNothing);

    await tester.tap(find.text('Explorer'));
    await tester.pump();

    expect(find.byType(ExplorerView), findsOneWidget);
    expect(find.byType(LibraryView), findsNothing);
  });

  testWidgets('queue shows a running dot while a download runs', (
    tester,
  ) async {
    await pumpHome(tester, tasks: [_task(TaskStatus.running)]);
    expect(find.byKey(const Key('queueRunningDot')), findsOneWidget);
  });

  testWidgets('queue has no running dot when nothing is running', (
    tester,
  ) async {
    await pumpHome(tester, tasks: [_task(TaskStatus.queued)]);
    expect(find.byKey(const Key('queueRunningDot')), findsNothing);
  });
}
