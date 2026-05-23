import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/library/data/folder_repository.dart';
import 'package:grabbit/features/library/presentation/explorer_view.dart';

// Drift `.watch()` streams never complete and stall widget tests, so the
// folder/item providers are driven by completing stubs keyed on the folder arg.
// (The real queries are covered in folder_repository_test.)
final _music = Folder(id: 1, name: 'Music', createdAt: DateTime.utc(2026));

MediaItem _item(String id, String title) => MediaItem(
  id: id,
  title: title,
  sourceUrl: 'u',
  site: 's',
  filePath: '/m/$id',
  type: 'video',
  createdAt: DateTime.utc(2026),
  storageState: 'private',
  isFavorite: false,
);

void main() {
  Future<void> pumpExplorer(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subfoldersProvider.overrideWith(
            (ref, parentId) =>
                Stream.value(parentId == null ? [_music] : <Folder>[]),
          ),
          folderItemsProvider.overrideWith(
            (ref, folderId) => Stream.value(
              folderId == null ? [_item('a', 'Root Clip')] : <MediaItem>[],
            ),
          ),
          folderItemCountsProvider.overrideWith(
            (ref) => Stream.value(<int, int>{1: 3}),
          ),
          breadcrumbProvider.overrideWith(
            (ref, folderId) async => folderId == null ? <Folder>[] : [_music],
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ExplorerView())),
      ),
    );
    // Two pumps: one to subscribe, one to deliver the Stream.value emissions
    // (folders/items/counts) so the body leaves the loading skeleton.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('renders root folders + items and navigates into a folder', (
    tester,
  ) async {
    await pumpExplorer(tester);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Root Clip'), findsOneWidget);

    await tester.tap(find.text('Music'));
    await tester.pump();
    await tester.pump();
    expect(find.text('This folder is empty'), findsOneWidget);
    expect(find.text('Root Clip'), findsNothing);
  });

  testWidgets('folder card shows the item count', (tester) async {
    await pumpExplorer(tester);
    expect(find.text('3 items'), findsOneWidget);
  });

  testWidgets('empty folder uses the shared EmptyState', (tester) async {
    await pumpExplorer(tester);
    await tester.tap(find.text('Music'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('long-press starts multi-select with a Move action', (
    tester,
  ) async {
    await pumpExplorer(tester);

    await tester.longPress(find.text('Root Clip'));
    await tester.pump();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Move'), findsOneWidget);
  });

  testWidgets('shows a skeleton while folders/items load', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Streams that never emit keep the providers in the loading state.
          subfoldersProvider.overrideWith(
            (ref, _) => Stream<List<Folder>>.fromFuture(
              Completer<List<Folder>>().future,
            ),
          ),
          folderItemsProvider.overrideWith(
            (ref, _) => Stream<List<MediaItem>>.fromFuture(
              Completer<List<MediaItem>>().future,
            ),
          ),
          folderItemCountsProvider.overrideWith(
            (ref) => Stream.value(<int, int>{}),
          ),
          breadcrumbProvider.overrideWith((ref, _) async => <Folder>[]),
        ],
        child: const MaterialApp(home: Scaffold(body: ExplorerView())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MediaGridSkeleton), findsOneWidget);
  });
}
