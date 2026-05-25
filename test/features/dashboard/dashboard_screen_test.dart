import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
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
import 'package:grabbit/features/library/presentation/suggested_albums_provider.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';

MediaItem _item(String id, int size) => MediaItem(
  id: id,
  title: id,
  sourceUrl: 'u',
  site: 'youtube',
  filePath: '/tmp/$id.mp4',
  type: 'video',
  sizeBytes: size,
  // Recent so the activity chart's 30-day window includes it.
  createdAt: DateTime.now().subtract(const Duration(days: 1)),
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
          // Charts read these directly; stub so they don't hit the real DB.
          sizeByTypeProvider.overrideWith(
            (ref) => Stream.value(<String, int>{'video': 80, 'audio': 40}),
          ),
          sizeBySiteProvider.overrideWith(
            (ref) => Stream.value(<String, int>{'youtube': 120}),
          ),
          // Content tiles read these directly; stub empty so they auto-hide
          // (the graph tile is hidden by the default UnavailableGraphStore).
          recentlyPlayedProvider.overrideWith(
            (ref) => Stream.value(<MediaItem>[]),
          ),
          duplicatesProvider.overrideWith(
            (ref) => Stream.value(<List<MediaItem>>[]),
          ),
          suggestedAlbumsProvider.overrideWith(
            (ref) => Future.value(<SuggestedAlbum>[]),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle(); // streams emit → summary resolves to data

    expect(find.text('In library'), findsOneWidget);
    expect(find.text('Storage used'), findsOneWidget);
    expect(find.text('150 B'), findsOneWidget); // 100 + 50 (stat card)
    expect(find.text('In queue'), findsOneWidget);
    expect(find.text('1 downloading'), findsOneWidget); // running subtitle
    expect(find.text('Collections'), findsOneWidget);
    // Charts: two storage donuts + the activity bar chart.
    expect(find.byType(PieChart), findsNWidgets(2));
    expect(find.byType(BarChart), findsOneWidget);
    // The "Recently added" row renders from the seeded library items.
    expect(find.text('Recently added'), findsOneWidget);
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
