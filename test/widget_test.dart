import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/app.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/notifications/data/notifications_repository.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/data/settings_repository.dart';

void main() {
  testWidgets('launches to the empty Dashboard (P10d)', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Seed onboarded settings so the router doesn't redirect to /disclaimer.
    await SettingsRepository(
      db,
    ).write(const SettingsModel(disclaimerAccepted: true, aiSetupSeen: true));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          filteredLibraryProvider.overrideWith((ref) => Stream.value(const [])),
          // Stub the streams the dashboard + nav badges aggregate (drift
          // .watch() never completes, which would hang the test's event loop).
          libraryItemsProvider.overrideWith(
            (ref) => Stream.value(<MediaItem>[]),
          ),
          queueTasksProvider.overrideWith(
            (ref) => Stream.value(<DownloadTask>[]),
          ),
          collectionsProvider.overrideWith(
            (ref) => Stream.value(<Collection>[]),
          ),
          notificationFeedProvider.overrideWith((ref) => const Stream.empty()),
          unreadNotificationCountProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
        child: const GrabBitApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The Dashboard is the default landing; 'Dashboard' shows on the nav chrome.
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Your dashboard is empty'), findsOneWidget);
  });
}
