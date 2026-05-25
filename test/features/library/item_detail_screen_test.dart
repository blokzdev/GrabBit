import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/item_detail_screen.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/related_provider.dart';

MediaItem _item({String storageState = 'private', DateTime? lastAccessedAt}) =>
    MediaItem(
      id: 'x',
      title: 'My Clip',
      sourceUrl: 'https://example.com/v',
      site: 'youtube',
      filePath: '/tmp/x.jpg',
      type: 'image',
      durationSec: 213,
      sizeBytes: 12900000,
      width: 1920,
      height: 1080,
      createdAt: DateTime.utc(2026, 5, 3),
      storageState: storageState,
      isFavorite: false,
      lastAccessedAt: lastAccessedAt,
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, MediaItem item) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          mediaItemByIdProvider('x').overrideWith((ref) => item),
          // Finite stubs so the live Drift watch streams don't stall the test.
          metadataForItemProvider(
            'x',
          ).overrideWith((ref) => Stream.value(null)),
          tagsForItemProvider('x').overrideWith((ref) => Stream.value(<Tag>[])),
          collectionsForItemProvider(
            'x',
          ).overrideWith((ref) => Stream.value(<Collection>[])),
        ],
        child: const MaterialApp(home: ItemDetailScreen(itemId: 'x')),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'renders detail chips and a Save to device action',
    (tester) async {
      await pump(tester, _item());

      expect(find.text('My Clip'), findsWidgets); // app bar + body title
      expect(find.text('IMAGE'), findsOneWidget);
      expect(find.text('1920×1080'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Save to device'),
        findsOneWidget,
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'an exported item shows the saved state, not the button',
    (tester) async {
      await pump(tester, _item(storageState: 'exported'));

      expect(find.text('Saved to device'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save to device'), findsNothing);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'app bar uses Favorite + a single overflow menu (P9i)',
    (tester) async {
      await pump(tester, _item());

      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
      expect(find.byTooltip('Favorite'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'shows a "More like this" carousel when related items exist',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final related = _item().copyWith(id: 'y', title: 'Related Clip');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            mediaItemByIdProvider('x').overrideWith((ref) => _item()),
            metadataForItemProvider(
              'x',
            ).overrideWith((ref) => Stream.value(null)),
            tagsForItemProvider(
              'x',
            ).overrideWith((ref) => Stream.value(<Tag>[])),
            collectionsForItemProvider(
              'x',
            ).overrideWith((ref) => Stream.value(<Collection>[])),
            relatedItemsProvider('x').overrideWith((ref) async => [related]),
          ],
          child: const MaterialApp(home: ItemDetailScreen(itemId: 'x')),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('More like this'), findsOneWidget);
      expect(find.text('Related Clip'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'body shows last-played and collection chips (P9i)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            mediaItemByIdProvider('x').overrideWith(
              (ref) => _item(lastAccessedAt: DateTime.utc(2026, 5, 10)),
            ),
            metadataForItemProvider(
              'x',
            ).overrideWith((ref) => Stream.value(null)),
            tagsForItemProvider(
              'x',
            ).overrideWith((ref) => Stream.value(<Tag>[])),
            collectionsForItemProvider('x').overrideWith(
              (ref) => Stream.value([
                Collection(id: 7, name: 'Faves', createdAt: DateTime.utc(2026)),
              ]),
            ),
          ],
          child: const MaterialApp(home: ItemDetailScreen(itemId: 'x')),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Last played'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Faves'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
