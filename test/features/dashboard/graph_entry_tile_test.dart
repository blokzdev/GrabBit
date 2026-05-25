import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/graph/graph_store_provider.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/graph_entry_tile.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';

import '../../support/graph_fakes.dart';

MediaItem _item(String id) => MediaItem(
  id: id,
  title: id,
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
  required bool available,
  required List<MediaItem> items,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        graphStoreProvider.overrideWithValue(
          FakeGraphStore(available: available),
        ),
        libraryItemsProvider.overrideWith((ref) => Stream.value(items)),
      ],
      child: const MaterialApp(home: Scaffold(body: GraphEntryTile())),
    ),
  );
}

void main() {
  testWidgets('shows the entry when the graph is available and items exist', (
    tester,
  ) async {
    await _pump(tester, available: true, items: [_item('a')]);
    await tester.pump();
    expect(find.text('Explore your library graph'), findsOneWidget);
    expect(find.textContaining("'a'"), findsOneWidget); // seed item title
  });

  testWidgets('auto-hides when the graph is unavailable', (tester) async {
    await _pump(tester, available: false, items: [_item('a')]);
    await tester.pump();
    expect(find.text('Explore your library graph'), findsNothing);
  });

  testWidgets('auto-hides when the library is empty', (tester) async {
    await _pump(tester, available: true, items: const []);
    await tester.pump();
    expect(find.text('Explore your library graph'), findsNothing);
  });
}
