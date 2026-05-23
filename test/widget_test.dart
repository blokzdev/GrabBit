import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/app.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';

void main() {
  testWidgets('launches to the empty Library screen', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          filteredLibraryProvider.overrideWith((ref) => Stream.value(const [])),
          // Stub the app-bar badge streams (drift .watch() never completes,
          // which would hang the test's event loop).
          queueTasksProvider.overrideWith(
            (ref) => Stream.value(<DownloadTask>[]),
          ),
          collectionsProvider.overrideWith(
            (ref) => Stream.value(<Collection>[]),
          ),
        ],
        child: const GrabBitApp(),
      ),
    );
    await tester.pump();

    // 'Library' now appears in both the nav destination and the
    // Library/Explorer toggle.
    expect(find.text('Library'), findsWidgets);
    expect(find.text('Your library is empty'), findsOneWidget);
  });
}
