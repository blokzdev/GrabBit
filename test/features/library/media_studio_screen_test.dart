import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/media_studio_screen.dart';

MediaItem _item({required String type, int? durationSec}) => MediaItem(
  id: 'x',
  title: 'My Clip',
  sourceUrl: 'https://example.com/v',
  site: 'youtube',
  filePath: '/tmp/x.${type == 'image' ? 'jpg' : 'mp4'}',
  type: type,
  durationSec: durationSec,
  createdAt: DateTime.utc(2026, 5, 3),
  storageState: 'private',
  isFavorite: false,
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, MediaItem item) async {
    // Tall surface so the lazy ListView realizes every tool card.
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          mediaItemByIdProvider('x').overrideWith((ref) => item),
        ],
        child: const MaterialApp(home: MediaStudioScreen(itemId: 'x')),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'video item exposes trim, transform and reverse tools',
    (tester) async {
      await pump(tester, _item(type: 'video', durationSec: 120));

      expect(find.text('Trim'), findsOneWidget);
      expect(find.text('Transform'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Reverse'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'image item exposes transform and convert tools',
    (tester) async {
      await pump(tester, _item(type: 'image'));

      expect(find.text('Transform'), findsOneWidget);
      expect(find.text('Convert'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'To PNG'), findsOneWidget);
      // No trim tool for images.
      expect(find.text('Trim'), findsNothing);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
