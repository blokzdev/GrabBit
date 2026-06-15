import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/share/external_share_service.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/clustered_albums_provider.dart';
import 'package:grabbit/features/library/presentation/collections_screen.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';
import 'package:grabbit/features/library/presentation/suggested_albums_provider.dart';

Collection _collection() =>
    Collection(id: 1, name: 'Faves', createdAt: DateTime.utc(2026));

MediaItem _item() => MediaItem(
  id: 'i1',
  title: 'Saved Clip',
  sourceUrl: 'https://example.com/v',
  site: 'youtube',
  filePath: '/tmp/i1.mp4',
  type: 'video',
  createdAt: DateTime.utc(2026),
  storageState: 'private',
  isFavorite: false,
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'list shows collection rows with item counts',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            collectionsProvider.overrideWith(
              (ref) => Stream.value([_collection()]),
            ),
            collectionItemCountsProvider.overrideWith(
              (ref) => Stream.value(<int, int>{1: 3}),
            ),
          ],
          child: const MaterialApp(home: CollectionsScreen()),
        ),
      );
      await settle(tester);

      expect(find.text('Faves'), findsOneWidget);
      expect(find.text('3 items'), findsOneWidget);

      // Rename + Delete now live behind the row's overflow menu (P9g).
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'list shows an empty state when there are no collections',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            collectionsProvider.overrideWith(
              (ref) => Stream.value(<Collection>[]),
            ),
            collectionItemCountsProvider.overrideWith(
              (ref) => Stream.value(<int, int>{}),
            ),
          ],
          child: const MaterialApp(home: CollectionsScreen()),
        ),
      );
      await settle(tester);

      expect(find.byType(EmptyState), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Albums tab lists platforms with counts',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            collectionsProvider.overrideWith(
              (ref) => Stream.value(<Collection>[]),
            ),
            collectionItemCountsProvider.overrideWith(
              (ref) => Stream.value(<int, int>{}),
            ),
            distinctSitesProvider.overrideWith(
              (ref) => Stream.value(['youtube']),
            ),
            siteCountsProvider.overrideWith(
              (ref) => Stream.value(<String, int>{'youtube': 2}),
            ),
            distinctUploadersProvider.overrideWith(
              (ref) => Stream.value(<String>[]),
            ),
            uploaderCountsProvider.overrideWith(
              (ref) => Stream.value(<String, int>{}),
            ),
            recentlyPlayedProvider.overrideWith(
              (ref) => Stream.value(<MediaItem>[]),
            ),
            duplicatesProvider.overrideWith(
              (ref) => Stream.value(<List<MediaItem>>[]),
            ),
            suggestedAlbumsProvider.overrideWith(
              (ref) async => const <SuggestedAlbum>[],
            ),
          ],
          child: const MaterialApp(home: CollectionsScreen()),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Albums'));
      await settle(tester);

      expect(find.text('Platforms'), findsOneWidget);
      expect(find.text('youtube'), findsOneWidget);
      expect(find.text('2 items'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Albums tab shows the Discovered section for clustered albums',
    (tester) async {
      MediaItem item(String id) => MediaItem(
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
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            collectionsProvider.overrideWith(
              (ref) => Stream.value(<Collection>[]),
            ),
            collectionItemCountsProvider.overrideWith(
              (ref) => Stream.value(<int, int>{}),
            ),
            distinctSitesProvider.overrideWith(
              (ref) => Stream.value(['youtube']),
            ),
            siteCountsProvider.overrideWith(
              (ref) => Stream.value(<String, int>{'youtube': 1}),
            ),
            distinctUploadersProvider.overrideWith(
              (ref) => Stream.value(<String>[]),
            ),
            uploaderCountsProvider.overrideWith(
              (ref) => Stream.value(<String, int>{}),
            ),
            recentlyPlayedProvider.overrideWith(
              (ref) => Stream.value(<MediaItem>[]),
            ),
            duplicatesProvider.overrideWith(
              (ref) => Stream.value(<List<MediaItem>>[]),
            ),
            suggestedAlbumsProvider.overrideWith(
              (ref) async => const <SuggestedAlbum>[],
            ),
            clusteredAlbumsProvider.overrideWith(
              (ref) async => [
                SuggestedAlbum(
                  label: "Around 'rock'",
                  items: [item('a'), item('b'), item('c')],
                ),
              ],
            ),
          ],
          child: const MaterialApp(home: CollectionsScreen()),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Albums'));
      await settle(tester);

      expect(find.text('Discovered'), findsOneWidget);
      expect(find.text("Around 'rock'"), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'Albums tab shows the Duplicates card when duplicates exist',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            collectionsProvider.overrideWith(
              (ref) => Stream.value(<Collection>[]),
            ),
            collectionItemCountsProvider.overrideWith(
              (ref) => Stream.value(<int, int>{}),
            ),
            distinctSitesProvider.overrideWith(
              (ref) => Stream.value(['youtube']),
            ),
            siteCountsProvider.overrideWith(
              (ref) => Stream.value(<String, int>{'youtube': 2}),
            ),
            distinctUploadersProvider.overrideWith(
              (ref) => Stream.value(<String>[]),
            ),
            uploaderCountsProvider.overrideWith(
              (ref) => Stream.value(<String, int>{}),
            ),
            recentlyPlayedProvider.overrideWith(
              (ref) => Stream.value(<MediaItem>[]),
            ),
            duplicatesProvider.overrideWith(
              (ref) => Stream.value([
                [_item(), _item()],
              ]),
            ),
            suggestedAlbumsProvider.overrideWith(
              (ref) async => const <SuggestedAlbum>[],
            ),
          ],
          child: const MaterialApp(home: CollectionsScreen()),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Albums'));
      await settle(tester);

      expect(find.text('Duplicates'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Review'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Clean up'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'detail shows the scoped media grid',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            collectionItemsProvider(
              1,
            ).overrideWith((ref) => Stream.value([_item()])),
          ],
          child: const MaterialApp(
            home: CollectionDetailScreen(collectionId: 1, name: 'Faves'),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Saved Clip'), findsOneWidget);
      expect(find.byType(MediaGrid), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'detail shows an empty state for an empty collection',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            collectionItemsProvider(
              1,
            ).overrideWith((ref) => Stream.value(<MediaItem>[])),
          ],
          child: const MaterialApp(
            home: CollectionDetailScreen(collectionId: 1, name: 'Faves'),
          ),
        ),
      );
      await settle(tester);

      expect(find.byType(EmptyState), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'detail app bar shares all and exposes rename/delete (P9i)',
    (tester) async {
      final share = _FakeShare();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            externalShareServiceProvider.overrideWithValue(share),
            collectionItemsProvider(
              1,
            ).overrideWith((ref) => Stream.value([_item()])),
          ],
          child: const MaterialApp(
            home: CollectionDetailScreen(collectionId: 1, name: 'Faves'),
          ),
        ),
      );
      await settle(tester);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Share all'));
      await tester.pumpAndSettle();
      expect(share.sharedPaths, isNotEmpty);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

class _FakeShare implements ExternalShareService {
  final List<String> sharedPaths = [];
  @override
  Future<void> shareFiles(List<String> paths) async =>
      sharedPaths.addAll(paths);
  @override
  Future<void> shareText(String text, {String? subject}) async {}
  @override
  Future<void> openUrl(String url) async {}
}
