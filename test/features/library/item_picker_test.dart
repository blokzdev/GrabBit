import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/presentation/item_picker.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';

MediaItem _item(String id) => MediaItem(
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

void main() {
  testWidgets('lists items (excluding self) and returns the tapped id', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryItemsProvider.overrideWith(
            (ref) => Stream.value([_item('a'), _item('b'), _item('c')]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  picked = await pickLibraryItem(context, excludeId: 'a');
                },
                child: const Text('pick'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();

    // Self ('a') is excluded; the others are offered.
    expect(find.text('Clip a'), findsNothing);
    expect(find.text('Clip b'), findsOneWidget);
    expect(find.text('Clip c'), findsOneWidget);

    await tester.tap(find.text('Clip c'));
    await tester.pumpAndSettle();
    expect(picked, 'c');
  });
}
