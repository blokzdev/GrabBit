import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/ai/presentation/relevant_items_screen.dart';
import 'package:grabbit/features/library/presentation/semantic_search_provider.dart';

MediaItem _item(String id) => MediaItem(
  id: id,
  title: 'Item $id',
  sourceUrl: 'u',
  site: 'youtube',
  filePath: '/tmp/$id',
  type: 'video',
  sizeBytes: 1,
  createdAt: DateTime.utc(2026),
  storageState: 'private',
  isFavorite: false,
);

Future<void> _pump(
  WidgetTester tester, {
  required bool ready,
  List<MediaItem> results = const [],
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        semanticSearchReadyProvider.overrideWith((ref) async => ready),
        semanticResultsProvider.overrideWith((ref, query) async => results),
      ],
      child: const MaterialApp(home: RelevantItemsScreen()),
    ),
  );
  await tester.pump(); // resolve the ready future
}

void main() {
  testWidgets('offers an on-ramp when semantic search isn\'t ready', (
    tester,
  ) async {
    await _pump(tester, ready: false);
    expect(find.text('Search isn\'t ready'), findsOneWidget);
    expect(find.text('Open AI settings'), findsOneWidget);
  });

  testWidgets('prompts for a query before anything is typed', (tester) async {
    await _pump(tester, ready: true);
    expect(find.text('Find items in your library'), findsOneWidget);
  });

  testWidgets('shows the most relevant items for a query', (tester) async {
    await _pump(tester, ready: true, results: [_item('a'), _item('b')]);

    await tester.enterText(find.byType(TextField), 'concert');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(); // apply the query
    await tester.pump(); // resolve the results future

    expect(find.text('Item a'), findsOneWidget);
    expect(find.text('Item b'), findsOneWidget);
  });

  testWidgets('shows an empty state when nothing matches', (tester) async {
    await _pump(tester, ready: true);

    await tester.enterText(find.byType(TextField), 'nothing');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump();

    expect(find.text('No matching items'), findsOneWidget);
  });
}
