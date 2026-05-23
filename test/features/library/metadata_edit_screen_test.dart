import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/metadata_edit_screen.dart';

MediaItem _item() => MediaItem(
  id: 'x',
  title: 'My Clip',
  sourceUrl: 'https://example.com/v',
  site: 'youtube',
  filePath: '/tmp/x.mp4',
  type: 'video',
  createdAt: DateTime.utc(2026, 5, 3),
  storageState: 'private',
  isFavorite: false,
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          mediaItemByIdProvider('x').overrideWith((ref) => _item()),
          // Finite stubs so the live Drift watch streams don't stall the test.
          tagsForItemProvider('x').overrideWith((ref) => Stream.value(<Tag>[])),
          collectionsProvider.overrideWith(
            (ref) => Stream.value(<Collection>[]),
          ),
          collectionsForItemProvider(
            'x',
          ).overrideWith((ref) => Stream.value(<Collection>[])),
        ],
        child: const MaterialApp(home: MetadataEditScreen(itemId: 'x')),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'renders the editable form with section headers and Save',
    (tester) async {
      await pump(tester);

      expect(find.text('My Clip'), findsOneWidget); // seeded title field
      expect(find.widgetWithText(TextButton, 'Save'), findsOneWidget);
      expect(find.widgetWithText(SectionHeader, 'Tags'), findsOneWidget);
      expect(find.text('Collections'), findsOneWidget);
      expect(find.text('No collections yet.'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
