import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/rediscover_row.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';
import 'package:grabbit/features/library/presentation/rediscover_provider.dart';

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

Future<void> _pump(WidgetTester tester, List<MediaItem> items) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [rediscoverProvider.overrideWith((ref) async => items)],
      child: const MaterialApp(home: Scaffold(body: RediscoverRow())),
    ),
  );
}

void main() {
  testWidgets('renders the header and tiles when there are items', (
    tester,
  ) async {
    await _pump(tester, [_item('a'), _item('b')]);
    await tester.pump();
    expect(find.text('Rediscover'), findsOneWidget);
    expect(find.byType(MediaTile), findsNWidgets(2));
  });

  testWidgets('auto-hides when empty', (tester) async {
    await _pump(tester, const []);
    await tester.pump();
    expect(find.text('Rediscover'), findsNothing);
    expect(find.byType(MediaTile), findsNothing);
  });
}
