import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/storage/disk_space_service.dart';
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
  Future<void> pump(WidgetTester tester, {DiskSpace? device}) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          sizeByTypeProvider.overrideWith(
            (ref) => Stream.value(<String, int>{'video': 150, 'audio': 20}),
          ),
          sizeBySiteProvider.overrideWith(
            (ref) => Stream.value(<String, int>{'youtube': 150, 'vimeo': 20}),
          ),
          largestItemsProvider.overrideWith((ref) => Stream.value([_item()])),
          deviceDiskSpaceProvider.overrideWith(
            (ref) async =>
                device ?? (freeBytes: 80 * 1024 * 1024 * 1024, totalBytes: 0),
          ),
        ],
        child: const MaterialApp(home: StorageScreen()),
      ),
    );
  }

  testWidgets('shows total, breakdown sections, and largest items', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();

    expect(find.text('170 B'), findsOneWidget); // app total
    expect(find.text('By type'), findsOneWidget);
    expect(find.text('By platform'), findsOneWidget);
    expect(find.text('Find duplicates'), findsOneWidget);
    expect(find.text('Big clip'), findsOneWidget);
  });

  testWidgets('shows device free/total when available (P9f)', (tester) async {
    await pump(
      tester,
      device: (
        freeBytes: 30 * 1024 * 1024 * 1024,
        totalBytes: 128 * 1024 * 1024 * 1024,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Device:'), findsOneWidget);
    expect(find.textContaining('30.0 GB free'), findsOneWidget);
  });

  testWidgets('cleanup tile is present and confirm-gated (P9f)', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();

    expect(find.text('Clean up leftover files'), findsOneWidget);
    await tester.tap(find.text('Clean up leftover files'));
    await tester.pumpAndSettle();

    // Confirmation dialog appears; declining is a no-op.
    expect(find.text('Clean up leftover files?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
