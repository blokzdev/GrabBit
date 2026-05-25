import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/recent_media_row.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';

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

Future<void> _pump(WidgetTester tester, {required Stream<List<MediaItem>> s}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [libraryItemsProvider.overrideWith((ref) => s)],
      child: MaterialApp(
        home: Scaffold(
          body: RecentMediaRow(
            title: 'Recently added',
            provider: libraryItemsProvider,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the title and media tiles when there are items', (
    tester,
  ) async {
    await _pump(tester, s: Stream.value([_item('a'), _item('b')]));
    await tester.pump();
    expect(find.text('Recently added'), findsOneWidget);
    expect(find.byType(MediaTile), findsNWidgets(2));
  });

  testWidgets('auto-hides when there are no items', (tester) async {
    await _pump(tester, s: Stream.value(<MediaItem>[]));
    await tester.pump();
    expect(find.text('Recently added'), findsNothing);
    expect(find.byType(MediaTile), findsNothing);
  });
}
