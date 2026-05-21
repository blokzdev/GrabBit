import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/library_screen.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';

/// LibraryScreen reads the queue + collections providers for its app-bar
/// badges; stub them so the widget tests don't touch a real database.
final _badgeStubs = [
  queueTasksProvider.overrideWith((ref) => Stream.value(<DownloadTask>[])),
  collectionsProvider.overrideWith((ref) => Stream.value(<Collection>[])),
];

MediaItem _sampleItem() => MediaItem(
  id: 'item1',
  title: 'Saved Clip',
  sourceUrl: 'https://youtu.be/x',
  site: 'youtube',
  filePath: '/tmp/item1.mp4',
  type: 'video',
  createdAt: DateTime.utc(2026),
  storageState: 'private',
);

void main() {
  testWidgets('renders saved library items', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._badgeStubs,
          filteredLibraryProvider.overrideWith(
            (ref) => Stream.value([_sampleItem()]),
          ),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Saved Clip'), findsOneWidget);
    expect(find.text('Your library is empty'), findsNothing);
  });

  testWidgets('shows empty state when there are no items', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._badgeStubs,
          filteredLibraryProvider.overrideWith(
            (ref) => Stream.value(<MediaItem>[]),
          ),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Your library is empty'), findsOneWidget);
  });
}
