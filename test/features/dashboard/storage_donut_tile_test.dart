import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/chart_message.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/storage_donut_tile.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Stream<Map<String, int>> stream,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [sizeByTypeProvider.overrideWith((ref) => stream)],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 220,
            child: StorageDonutTile(
              provider: sizeByTypeProvider,
              maxSlices: 3,
              capitalizeLabels: true,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders a pie chart and a capitalized legend on data', (
    tester,
  ) async {
    await _pump(tester, stream: Stream.value({'video': 100, 'audio': 50}));
    await tester.pump();

    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('Video'), findsOneWidget); // capitalized label
    expect(find.text('150 B'), findsOneWidget); // center total
  });

  testWidgets('shows an empty state when there is no storage data', (
    tester,
  ) async {
    await _pump(tester, stream: Stream.value(<String, int>{}));
    await tester.pump();
    expect(find.byType(ChartMessage), findsOneWidget);
    expect(find.text('No storage data yet'), findsOneWidget);
    expect(find.byType(PieChart), findsNothing);
  });

  testWidgets('shows a shimmer skeleton while loading', (tester) async {
    await _pump(
      tester,
      stream: Completer<Map<String, int>>().future.asStream(),
    );
    await tester.pump();
    expect(find.byType(Shimmer), findsOneWidget);
  });

  testWidgets('surfaces an error with retry', (tester) async {
    await _pump(
      tester,
      stream: Stream<Map<String, int>>.error(Exception('boom')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ChartMessage), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
