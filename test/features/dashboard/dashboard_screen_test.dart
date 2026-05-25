import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/dashboard/presentation/dashboard_screen.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/storage_screen.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';

MediaItem _item(String id, int size) => MediaItem(
  id: id,
  title: id,
  sourceUrl: 'u',
  site: 'youtube',
  filePath: '/tmp/$id.mp4',
  type: 'video',
  sizeBytes: size,
  createdAt: DateTime.utc(2026),
  storageState: 'private',
  isFavorite: false,
);

DownloadTask _task(String status) => DownloadTask(
  id: 't-$status',
  url: 'u',
  requestJson: '{}',
  status: status,
  progress: 0,
  retries: 0,
  createdAt: DateTime.utc(2026),
  orderIndex: 0,
);

void main() {
  testWidgets('renders stat cards with aggregated values', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryItemsProvider.overrideWith(
            (ref) => Stream.value([_item('a', 100), _item('b', 50)]),
          ),
          queueTasksProvider.overrideWith(
            (ref) => Stream.value([
              _task(TaskStatus.running),
              _task(TaskStatus.queued),
            ]),
          ),
          collectionsProvider.overrideWith(
            (ref) => Stream.value(<Collection>[]),
          ),
          deviceDiskSpaceProvider.overrideWith(
            (ref) async => (freeBytes: 0, totalBytes: 0),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle(); // streams emit → summary resolves to data

    expect(find.text('In library'), findsOneWidget);
    expect(find.text('Storage used'), findsOneWidget);
    expect(find.text('150 B'), findsOneWidget); // 100 + 50
    expect(find.text('In queue'), findsOneWidget);
    expect(find.text('1 downloading'), findsOneWidget); // running subtitle
    expect(find.text('Collections'), findsOneWidget);
  });

  testWidgets('shows an empty state on a fresh install', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryItemsProvider.overrideWith(
            (ref) => Stream.value(<MediaItem>[]),
          ),
          queueTasksProvider.overrideWith(
            (ref) => Stream.value(<DownloadTask>[]),
          ),
          collectionsProvider.overrideWith(
            (ref) => Stream.value(<Collection>[]),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle(); // streams emit → summary resolves to data

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Your dashboard is empty'), findsOneWidget);
  });

  testWidgets('shows a shimmering skeleton while loading', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryItemsProvider.overrideWith(
            (ref) => Completer<List<MediaItem>>().future.asStream(),
          ),
          queueTasksProvider.overrideWith(
            (ref) => Completer<List<DownloadTask>>().future.asStream(),
          ),
          collectionsProvider.overrideWith(
            (ref) => Completer<List<Collection>>().future.asStream(),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(Shimmer), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('surfaces an error with retry', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryItemsProvider.overrideWith(
            (ref) => Stream<List<MediaItem>>.error(Exception('boom')),
          ),
          queueTasksProvider.overrideWith(
            (ref) => Stream.value(<DownloadTask>[]),
          ),
          collectionsProvider.overrideWith(
            (ref) => Stream.value(<Collection>[]),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ErrorView), findsOneWidget);
    expect(
      find.textContaining('Failed to load your dashboard'),
      findsOneWidget,
    );
  });
}
