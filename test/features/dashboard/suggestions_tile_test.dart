import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/suggestions_tile.dart';
import 'package:grabbit/features/library/presentation/suggested_albums_provider.dart';

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
  required Future<List<SuggestedAlbum>> future,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [suggestedAlbumsProvider.overrideWith((ref) => future)],
      child: const MaterialApp(home: Scaffold(body: SuggestionsTile())),
    ),
  );
}

void main() {
  testWidgets('lists suggested albums when present', (tester) async {
    await _pump(
      tester,
      future: Future.value([
        SuggestedAlbum(label: "Like 'Trip'", items: [_item('a'), _item('b')]),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Suggested for you'), findsOneWidget);
    expect(find.text("Like 'Trip'"), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
  });

  testWidgets(
    'auto-hides when there are no suggestions (AI off / no clusters)',
    (tester) async {
      await _pump(tester, future: Future.value(const <SuggestedAlbum>[]));
      await tester.pumpAndSettle();
      expect(find.text('Suggested for you'), findsNothing);
    },
  );
}
