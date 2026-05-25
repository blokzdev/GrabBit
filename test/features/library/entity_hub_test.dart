import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/entity_hub_screen.dart';
import 'package:grabbit/features/library/presentation/graph_entity_providers.dart';

MediaItem _item({required String id, required String title}) => MediaItem(
  id: id,
  title: title,
  sourceUrl: 'https://y/$id',
  site: 'youtube',
  filePath: '/m/$id',
  type: 'video',
  createdAt: DateTime.utc(2026),
  storageState: 'private',
  isFavorite: false,
);

void main() {
  group('hubItemsProvider', () {
    late AppDatabase db;
    late MetadataRepository repo;
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = MetadataRepository(db);
    });
    tearDown(() => db.close());

    Future<void> seed(String id, {String site = 'youtube'}) => db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: id,
            title: id,
            sourceUrl: 'https://y/$id',
            site: site,
            filePath: '/m/$id',
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
          ),
        );

    // Reads the first emission of a (Stream) hub provider. A live listener keeps
    // the underlying Drift stream subscribed so `.future` resolves.
    Future<List<MediaItem>> hubItems(({String type, String value}) key) {
      final c = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);
      c.listen(hubItemsProvider(key), (_, _) {});
      return c.read(hubItemsProvider(key).future);
    }

    test('tag hub returns only items with that tag', () async {
      await seed('a');
      await seed('b');
      await repo.addTagToItem('a', 'funny');
      final rows = await hubItems((type: 'tag', value: 'funny'));
      expect(rows.map((r) => r.id), ['a']);
    });

    test('uploader hub returns only that channel', () async {
      await seed('a');
      await seed('b');
      await db
          .into(db.mediaMetadata)
          .insert(
            MediaMetadataCompanion.insert(
              itemId: 'a',
              uploader: const Value('Rick'),
            ),
          );
      final rows = await hubItems((type: 'uploader', value: 'Rick'));
      expect(rows.map((r) => r.id), ['a']);
    });

    test('site hub filters by platform', () async {
      await seed('a', site: 'youtube');
      await seed('b', site: 'tiktok');
      final rows = await hubItems((type: 'site', value: 'tiktok'));
      expect(rows.map((r) => r.id), ['b']);
    });
  });

  group('EntityHubScreen', () {
    testWidgets('renders the display name, type label and a grid', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hubItemsProvider((type: 'tag', value: 'funny')).overrideWith(
              (ref) => Stream.value([_item(id: 'a', title: 'Tagged Clip')]),
            ),
          ],
          child: const MaterialApp(
            home: EntityHubScreen(
              type: 'tag',
              value: 'funny',
              displayName: 'funny',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('funny'), findsOneWidget); // app bar title
      expect(find.text('Tag'), findsOneWidget); // type label
      expect(find.text('Tagged Clip'), findsOneWidget);
    });

    testWidgets('renders a related-tags strip from the graph', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hubItemsProvider((type: 'tag', value: 'funny')).overrideWith(
              (ref) => Stream.value([_item(id: 'a', title: 'Tagged Clip')]),
            ),
            relatedTagsProvider((
              type: 'tag',
              value: 'funny',
            )).overrideWith((ref) async => ['cats', 'dogs']),
          ],
          child: const MaterialApp(
            home: EntityHubScreen(
              type: 'tag',
              value: 'funny',
              displayName: 'funny',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Related tags'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'cats'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'dogs'), findsOneWidget);
    });

    testWidgets('shows the empty state when the entity has no items', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hubItemsProvider((
              type: 'site',
              value: 'vimeo',
            )).overrideWith((ref) => Stream.value(<MediaItem>[])),
          ],
          child: const MaterialApp(
            home: EntityHubScreen(type: 'site', value: 'vimeo'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Nothing here'), findsOneWidget);
    });
  });
}
