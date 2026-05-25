import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/duplicates_screen.dart';

MediaItem _item(String id) => MediaItem(
  id: id,
  title: 'Clip $id',
  sourceUrl: 'https://y/$id',
  site: 'youtube',
  filePath: '/m/$id.mp4',
  type: 'video',
  createdAt: DateTime.utc(2026),
  storageState: 'private',
  isFavorite: false,
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, List<List<MediaItem>> groups) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          duplicatesProvider.overrideWith((ref) => Stream.value(groups)),
        ],
        child: const MaterialApp(home: DuplicatesScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows Clean up + a Keep badge when duplicates exist', (
    tester,
  ) async {
    await pump(tester, [
      [_item('a'), _item('b')],
    ]);

    expect(find.widgetWithText(TextButton, 'Clean up'), findsOneWidget);
    // Only the kept (oldest) row is badged.
    expect(find.text('Keep'), findsOneWidget);
    expect(find.text('2 copies'), findsOneWidget);
  });

  testWidgets('no Clean up action when there are no duplicates', (
    tester,
  ) async {
    await pump(tester, const []);

    expect(find.widgetWithText(TextButton, 'Clean up'), findsNothing);
    expect(find.text('No duplicates found'), findsNothing); // not yet scanned
  });
}
