import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/graph/graph_query_provider.dart';
import 'package:grabbit/core/graph/graph_query_service.dart';
import 'package:grabbit/features/library/presentation/semantic_search_provider.dart';
import 'package:grabbit/features/library/presentation/suggested_album_screen.dart';
import 'package:grabbit/features/library/presentation/suggested_albums_provider.dart';

import '../../support/graph_fakes.dart';

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
  group('suggestedAlbumsProvider', () {
    test('empty when the embedder is not ready', () async {
      final c = ProviderContainer(
        overrides: [
          semanticSearchReadyProvider.overrideWith((ref) async => false),
        ],
      );
      addTearDown(c.dispose);
      expect(await c.read(suggestedAlbumsProvider.future), isEmpty);
    });

    test('hydrates similarity clusters into albums when ready', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      for (final id in ['a', 'b', 'c']) {
        await db
            .into(db.mediaItems)
            .insert(
              MediaItemsCompanion.insert(
                id: id,
                title: 'Clip $id',
                sourceUrl: 'https://y/$id',
                site: 'youtube',
                filePath: '/m/$id',
                type: 'video',
                createdAt: DateTime.utc(2026, 1, id.codeUnitAt(0)),
                storageState: 'private',
              ),
            );
      }
      final store = FakeGraphStore(
        responder: (script) {
          if (script.contains('*embedding{id, v}')) {
            return {
              'headers': ['id', 'v'],
              'rows': [
                [
                  'a',
                  <double>[1, 0],
                ],
                [
                  'b',
                  <double>[1, 0.02],
                ],
                [
                  'c',
                  <double>[1, 0.04],
                ],
              ],
            };
          }
          return const {'rows': <List<Object?>>[]};
        },
      );
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          graphQueryServiceProvider.overrideWithValue(GraphQueryService(store)),
          semanticSearchReadyProvider.overrideWith((ref) async => true),
        ],
      );
      addTearDown(c.dispose);

      final albums = await c.read(suggestedAlbumsProvider.future);
      expect(albums, hasLength(1));
      expect(albums.single.items.map((m) => m.id).toSet(), {'a', 'b', 'c'});
      expect(albums.single.label, startsWith('Like '));
    });
  });

  group('SuggestedAlbumScreen', () {
    testWidgets('renders the grid and a Save action', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final album = SuggestedAlbum(
        label: "Like 'X'",
        items: [_item('a'), _item('b'), _item('c')],
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: SuggestedAlbumScreen(album: album)),
        ),
      );
      await tester.pump();

      expect(find.text("Like 'X'"), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
      expect(find.text('Clip a'), findsOneWidget);
    });

    testWidgets('shows the empty state for a missing album', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SuggestedAlbumScreen(album: null)),
        ),
      );
      await tester.pump();

      expect(find.text('Nothing here'), findsOneWidget);
    });
  });
}
