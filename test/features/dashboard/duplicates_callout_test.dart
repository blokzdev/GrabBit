import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/duplicates_callout.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';

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
  required Stream<List<List<MediaItem>>> s,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [duplicatesProvider.overrideWith((ref) => s)],
      child: const MaterialApp(home: Scaffold(body: DuplicatesCallout())),
    ),
  );
}

void main() {
  testWidgets('shows the count and Review when duplicates exist', (
    tester,
  ) async {
    await _pump(
      tester,
      s: Stream.value([
        [_item('a'), _item('b')], // one group, one extra copy
      ]),
    );
    await tester.pump();
    expect(find.text('Review'), findsOneWidget);
    expect(find.textContaining('1 group'), findsOneWidget);
    expect(find.textContaining('1 extra copy'), findsOneWidget);
  });

  testWidgets('auto-hides when there are no duplicates', (tester) async {
    await _pump(tester, s: Stream.value(const <List<MediaItem>>[]));
    await tester.pump();
    expect(find.text('Review'), findsNothing);
  });
}
