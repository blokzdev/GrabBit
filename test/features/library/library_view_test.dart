import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/library_view.dart';
import 'package:grabbit/features/library/presentation/media_selection_bar.dart';

MediaItem _sampleItem({String id = 'item1', String title = 'Saved Clip'}) =>
    MediaItem(
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

  testWidgets('renders saved library items', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filteredLibraryProvider.overrideWith(
            (ref) => Stream.value([_sampleItem()]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: LibraryView())),
      ),
    );
    await tester.pump();

    expect(find.text('Saved Clip'), findsOneWidget);
    expect(find.text('Your library is empty'), findsNothing);
  });

  testWidgets('shows empty state when there are no items', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filteredLibraryProvider.overrideWith(
            (ref) => Stream.value(<MediaItem>[]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: LibraryView())),
      ),
    );
    await tester.pump();

    expect(find.text('Your library is empty'), findsOneWidget);
  });

  testWidgets('shows a skeleton grid while loading', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filteredLibraryProvider.overrideWith(
            // A stream that never emits keeps the provider in the loading state.
            (ref) => Stream<List<MediaItem>>.fromFuture(
              Completer<List<MediaItem>>().future,
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: LibraryView())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MediaGridSkeleton), findsOneWidget);
  });

  testWidgets('Select from the menu enters multi-select with the bar', (
    tester,
  ) async {
    tallSurface(tester);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          filteredLibraryProvider.overrideWith(
            (ref) => Stream.value([_sampleItem()]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: LibraryView())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MediaSelectionBar), findsNothing);

    await tester.longPress(find.text('Saved Clip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(find.byType(MediaSelectionBar), findsOneWidget);
    expect(find.text('1 selected'), findsOneWidget);

    // Clear exits selection.
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaSelectionBar), findsNothing);
  });

  testWidgets('tapping more tiles grows the count in selection mode', (
    tester,
  ) async {
    tallSurface(tester);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          filteredLibraryProvider.overrideWith(
            (ref) => Stream.value([
              _sampleItem(),
              _sampleItem(id: 'item2', title: 'Second Clip'),
            ]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: LibraryView())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Saved Clip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    // Now in selection mode, a tap toggles the second tile.
    await tester.tap(find.text('Second Clip'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
  });

  testWidgets('bulk delete removes the selected rows', (tester) async {
    tallSurface(tester);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    Future<void> seed(String id) => db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: id,
            title: id,
            sourceUrl: 'u',
            site: 'youtube',
            filePath: '/tmp/$id.mp4',
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
          ),
        );
    await seed('a');
    await seed('b');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          filteredLibraryProvider.overrideWith(
            (ref) => Stream.value([
              _sampleItem(id: 'a', title: 'a'),
              _sampleItem(id: 'b', title: 'b'),
            ]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: LibraryView())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('b'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await db.select(db.mediaItems).get(), isEmpty);
  });
}
