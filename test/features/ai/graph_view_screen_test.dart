import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/graph/graph_query_service.dart';
import 'package:grabbit/core/graph/graph_store_provider.dart';
import 'package:grabbit/features/ai/presentation/graph_view_providers.dart';
import 'package:grabbit/features/ai/presentation/graph_view_screen.dart';
import 'package:grabbit/features/library/presentation/connection_path_provider.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';

import '../../support/graph_fakes.dart';

MediaItem _item(String id) => MediaItem(
  id: id,
  title: 'Clip $id',
  sourceUrl: 'u',
  site: 'youtube',
  filePath: '/m/$id',
  type: 'video',
  createdAt: DateTime.utc(2026),
  storageState: 'private',
  isFavorite: false,
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(
    WidgetTester tester, {
    required bool available,
    required List<GraphNeighbor> neighbors,
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          graphStoreProvider.overrideWithValue(
            FakeGraphStore(available: available),
          ),
          mediaItemByIdProvider('x').overrideWith((ref) => null),
          graphNeighborhoodProvider('x').overrideWith((ref) async => neighbors),
          ...extra,
        ],
        child: const MaterialApp(home: GraphViewScreen(itemId: 'x')),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the unavailable state when the graph is off', (
    tester,
  ) async {
    await pump(tester, available: false, neighbors: const []);
    expect(find.text('Graph unavailable'), findsOneWidget);
  });

  testWidgets('shows the empty state when the item has no connections', (
    tester,
  ) async {
    await pump(tester, available: true, neighbors: const []);
    expect(find.text('No connections yet'), findsOneWidget);
  });

  testWidgets('renders the legend when there is a neighborhood', (
    tester,
  ) async {
    await pump(
      tester,
      available: true,
      neighbors: const [
        GraphNeighbor(relation: 'uploader', id: 'u1', label: 'Rick'),
        GraphNeighbor(relation: 'tag', id: 't1', label: 'funny'),
      ],
    );
    // The legend filters (sibling overlay, independent of graph layout) read,
    // showing only the relations present, selected (visible) and wired to toggle.
    final channel = find.widgetWithText(FilterChip, 'Channel');
    expect(channel, findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Tag'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Platform'), findsNothing);
    expect(tester.widget<FilterChip>(channel).selected, isTrue);
    expect(tester.widget<FilterChip>(channel).onSelected, isNotNull);
    expect(find.text('Graph unavailable'), findsNothing);
    expect(find.text('No connections yet'), findsNothing);
  });

  testWidgets('shows zoom controls and the Find path action (P13e-3b)', (
    tester,
  ) async {
    await pump(
      tester,
      available: true,
      neighbors: const [GraphNeighbor(relation: 'tag', id: 't1', label: 'fun')],
    );
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Zoom out'), findsOneWidget);
    expect(find.byTooltip('Reset view'), findsOneWidget);
    expect(find.byTooltip('Find path…'), findsOneWidget);
  });

  testWidgets('Find path → pick → path banner, then back restores it', (
    tester,
  ) async {
    await pump(
      tester,
      available: true,
      neighbors: const [GraphNeighbor(relation: 'tag', id: 't1', label: 'fun')],
      extra: [
        libraryItemsProvider.overrideWith((ref) => Stream.value([_item('y')])),
        connectionPathProvider(('x', 'y')).overrideWith(
          (ref) async => ConnectionPathView(
            items: [_item('x'), _item('y')],
            connectors: const ['same channel'],
          ),
        ),
      ],
    );

    await tester.tap(find.byTooltip('Find path…'));
    await tester.pumpAndSettle();
    expect(find.text('Clip y'), findsOneWidget); // picker lists the target

    await tester.tap(find.text('Clip y'));
    await tester.pumpAndSettle();
    expect(find.text('Clip x → Clip y'), findsOneWidget); // path banner

    await tester.tap(find.byTooltip('Back to neighborhood'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterChip, 'Tag'), findsOneWidget); // restored
  });

  testWidgets('path mode shows "No connection found" for islands', (
    tester,
  ) async {
    await pump(
      tester,
      available: true,
      neighbors: const [GraphNeighbor(relation: 'tag', id: 't1', label: 'fun')],
      extra: [
        libraryItemsProvider.overrideWith((ref) => Stream.value([_item('y')])),
        connectionPathProvider(('x', 'y')).overrideWith((ref) async => null),
      ],
    );

    await tester.tap(find.byTooltip('Find path…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clip y'));
    await tester.pumpAndSettle();
    expect(find.text('No connection found'), findsOneWidget);
  });
}
