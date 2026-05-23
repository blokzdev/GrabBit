import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
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

Widget _host(MediaItem item) => MaterialApp(
  home: Scaffold(body: MediaTile(item: item)),
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
}
