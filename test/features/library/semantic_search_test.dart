import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/library_view.dart';
import 'package:grabbit/features/library/presentation/semantic_search_provider.dart';

MediaItem _item({required String id, required String title}) => MediaItem(
  id: id,
  title: title,
  sourceUrl: 'https://youtu.be/$id',
  site: 'youtube',
  filePath: '/tmp/$id.mp4',
  type: 'video',
  createdAt: DateTime.utc(2026),
  storageState: 'private',
  isFavorite: false,
);

void main() {
  void tallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget harness({
    required bool ready,
    Future<List<MediaItem>> Function(String query)? semanticResults,
    AppDatabase? db,
  }) => ProviderScope(
    overrides: [
      if (db != null) appDatabaseProvider.overrideWithValue(db),
      semanticSearchReadyProvider.overrideWith((ref) async => ready),
      filteredLibraryProvider.overrideWith(
        (ref) => Stream.value([_item(id: 'lib', title: 'A Library Item')]),
      ),
      semanticResultsProvider.overrideWith(
        (ref, query) async => semanticResults?.call(query) ?? const [],
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: LibraryView())),
  );

  testWidgets('no Smart toggle when the embedder is not ready', (tester) async {
    await tester.pumpWidget(harness(ready: false));
    await tester.pumpAndSettle();

    expect(find.text('Smart'), findsNothing);
    expect(find.text('A Library Item'), findsOneWidget); // text mode default
  });

  testWidgets('Smart toggle appears when ready and prompts before a query', (
    tester,
  ) async {
    tallSurface(tester);
    await tester.pumpWidget(harness(ready: true));
    await tester.pumpAndSettle();

    expect(find.text('Smart'), findsOneWidget);

    await tester.tap(find.text('Smart'));
    await tester.pumpAndSettle();

    // No query submitted yet → the smart prompt, not the library-empty state.
    expect(find.text('Smart search'), findsOneWidget);
  });

  testWidgets('submitting a smart query renders ranked results', (
    tester,
  ) async {
    tallSurface(tester);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      harness(
        ready: true,
        db: db,
        semanticResults: (query) async => query.isEmpty
            ? const []
            : [_item(id: 'hit', title: 'Semantic Hit')],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Smart'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'beach sunset');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Semantic Hit'), findsOneWidget);
  });
}
