import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/activity_chart_tile.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/chart_message.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';

MediaItem _recentItem() => MediaItem(
  id: 'a',
  title: 't',
  sourceUrl: 'u',
  site: 'youtube',
  filePath: '/tmp/x',
  type: 'video',
  sizeBytes: 1,
  createdAt: DateTime.now().subtract(const Duration(days: 1)),
  storageState: 'private',
  isFavorite: false,
);

Future<void> _pump(
  WidgetTester tester, {
  required Stream<List<MediaItem>> stream,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [libraryItemsProvider.overrideWith((ref) => stream)],
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 400, height: 220, child: ActivityChartTile()),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders a bar chart when there is recent activity', (
    tester,
  ) async {
    await _pump(tester, stream: Stream.value([_recentItem()]));
    await tester.pump();
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('shows an empty state with no activity', (tester) async {
    await _pump(tester, stream: Stream.value(<MediaItem>[]));
    await tester.pump();
    expect(find.byType(ChartMessage), findsOneWidget);
    expect(find.text('No activity yet'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('shows a shimmer skeleton while loading', (tester) async {
    await _pump(tester, stream: Completer<List<MediaItem>>().future.asStream());
    await tester.pump();
    expect(find.byType(Shimmer), findsOneWidget);
  });

  testWidgets('surfaces an error with retry', (tester) async {
    await _pump(
      tester,
      stream: Stream<List<MediaItem>>.error(Exception('boom')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ChartMessage), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
