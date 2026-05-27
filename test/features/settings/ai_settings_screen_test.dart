import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/graph/graph_store_provider.dart';
import 'package:grabbit/core/graph/graph_sync_provider.dart';
import 'package:grabbit/core/graph/graph_sync_service.dart';
import 'package:grabbit/features/notifications/data/notification_enums.dart';
import 'package:grabbit/features/settings/presentation/ai_settings_screen.dart';

void main() {
  testWidgets('renders the AI & graph controls', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: AiSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rebuild graph index'), findsOneWidget);
    expect(find.text('Semantic search'), findsOneWidget);
    expect(find.text('Test embedder'), findsOneWidget);
  });

  testWidgets('rebuilding the graph posts an activity entry (P11c)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          // Real service, but skip start() so no table-update listener (and its
          // close-timer) is created in the test.
          graphSyncServiceProvider.overrideWith(
            (ref) => GraphSyncService(
              ref.watch(graphStoreProvider),
              ref.watch(appDatabaseProvider),
            ),
          ),
        ],
        child: const MaterialApp(home: AiSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rebuild graph index'));
    await tester.pumpAndSettle();

    final notifs = await db.select(db.notifications).get();
    expect(notifs, hasLength(1));
    expect(notifs.single.category, NotificationCategory.graph);
    // On a CI / non-arm64 host the graph engine is unavailable → a warning entry.
    expect(notifs.single.severity, NotificationSeverity.warning);
  });
}
