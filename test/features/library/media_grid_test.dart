import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';

MediaItem _item({required String id, required String type}) => MediaItem(
  id: id,
  title: 'Clip $id',
  sourceUrl: 'https://example.com/$id',
  site: 'youtube',
  filePath: '/tmp/$id',
  type: type,
  createdAt: DateTime.utc(2026),
  storageState: 'private',
  isFavorite: false,
);

Widget _host(MediaItem item) => ProviderScope(
  child: MaterialApp(
    home: Scaffold(body: MediaTile(item: item)),
  ),
);

void main() {
  testWidgets('video tiles show a play badge', (tester) async {
    await tester.pumpWidget(_host(_item(id: 'v', type: 'video')));
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('audio tiles show no play badge', (tester) async {
    await tester.pumpWidget(_host(_item(id: 'a', type: 'audio')));
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.byIcon(Icons.music_note), findsOneWidget);
  });

  testWidgets('thumbnail is wrapped in a Hero keyed by item id', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_item(id: 'h', type: 'video')));
    expect(
      find.byWidgetPredicate((w) => w is Hero && w.tag == mediaHeroTag('h')),
      findsOneWidget,
    );
  });

  testWidgets(
    'image item with no thumbnail renders the image file, not a movie icon (P13b-3)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MediaThumb(
                item: _item(id: 'i', type: 'image'),
              ),
            ),
          ),
        ),
      );
      // Falls back to Image.file(filePath) — never the video placeholder.
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.movie_outlined), findsNothing);
    },
  );

  testWidgets('video item with no thumbnail shows the movie placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: MediaThumb(
              item: _item(id: 'v2', type: 'video'),
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('tapping the star favorites the item', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: 'v',
            title: 'Clip v',
            sourceUrl: 'u',
            site: 'youtube',
            filePath: '/tmp/v',
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: MediaTile(
              item: _item(id: 'v', type: 'video'),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.star_outline), findsOneWidget);
    await tester.tap(find.byIcon(Icons.star_outline));
    await tester.pump();

    final row = await (db.select(
      db.mediaItems,
    )..where((t) => t.id.equals('v'))).getSingle();
    expect(row.isFavorite, isTrue);
  });
}
