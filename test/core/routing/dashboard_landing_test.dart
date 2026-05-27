import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/app.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/dashboard/presentation/dashboard_screen.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/home_screen.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/notifications/data/notifications_repository.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/data/settings_repository.dart';

Future<void> _pumpApp(WidgetTester tester) async {
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
        // Stub the streams the Dashboard aggregates; the real drift .watch()
        // leaves a pending timer on disposal that fails the test.
        libraryItemsProvider.overrideWith((ref) => Stream.value(<MediaItem>[])),
        queueTasksProvider.overrideWith(
          (ref) => Stream.value(<DownloadTask>[]),
        ),
        collectionsProvider.overrideWith((ref) => Stream.value(<Collection>[])),
        notificationFeedProvider.overrideWith((ref) => const Stream.empty()),
        unreadNotificationCountProvider.overrideWith(
          (ref) => const Stream.empty(),
        ),
      ],
      child: const GrabBitApp(),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the app lands on the Dashboard at /', (tester) async {
    await _pumpApp(tester);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('the Library destination opens HomeScreen at /library', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle();
    // The Library destination's unselected icon (unique vs the dashboard icon).
    await tester.tap(find.byIcon(Icons.video_library_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
