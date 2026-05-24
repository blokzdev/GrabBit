import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/storage_screen.dart';

MediaItem _item() => MediaItem(
  id: 'big',
  title: 'Big clip',
  sourceUrl: 'u',
  site: 'youtube',
  filePath: '/tmp/big.mp4',
  type: 'video',
  sizeBytes: 150,
  createdAt: DateTime.utc(2026),
  storageState: 'private',
  isFavorite: false,
);

void main() {
  testWidgets('shows total, breakdown sections, and largest items', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sizeByTypeProvider.overrideWith(
            (ref) => Stream.value(<String, int>{'video': 150, 'audio': 20}),
          ),
          sizeBySiteProvider.overrideWith(
            (ref) => Stream.value(<String, int>{'youtube': 150, 'vimeo': 20}),
          ),
          largestItemsProvider.overrideWith((ref) => Stream.value([_item()])),
        ],
        child: const MaterialApp(home: StorageScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('170 B'), findsOneWidget); // total
    expect(find.text('By type'), findsOneWidget);
    expect(find.text('By platform'), findsOneWidget);
    expect(find.text('Find duplicates'), findsOneWidget);
    expect(find.text('Big clip'), findsOneWidget);
  });
}
