import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/ai/downloaded_models_provider.dart';
import 'package:grabbit/core/ai/generation_model.dart';
import 'package:grabbit/core/device/device_profile.dart';
import 'package:grabbit/core/device/device_tier_provider.dart';
import 'package:grabbit/core/graph/graph_store_provider.dart';
import 'package:grabbit/core/graph/graph_sync_provider.dart';
import 'package:grabbit/core/graph/graph_sync_service.dart';
import 'package:grabbit/features/notifications/data/notification_enums.dart';
import 'package:grabbit/features/settings/presentation/ai_settings_screen.dart';

class _FixedTier extends ActiveDeviceTier {
  _FixedTier(this._tier);
  final DeviceTier _tier;
  @override
  DeviceTier build() => _tier;
}

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

  testWidgets('shows the device-tier banner (P12g)', (tester) async {
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
          activeDeviceTierProvider.overrideWith(
            () => _FixedTier(DeviceTier.high),
          ),
        ],
        child: const MaterialApp(home: AiSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your device: ${DeviceTier.high.label}'), findsOneWidget);
    expect(find.text(DeviceTier.high.blurb), findsOneWidget);
  });

  testWidgets('low tier shows the generation disabled-reason tile (P12g)', (
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
          activeDeviceTierProvider.overrideWith(
            () => _FixedTier(DeviceTier.low),
          ),
        ],
        child: const MaterialApp(home: AiSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Generation is gated off on low tier → a legible reason, not a silent gap.
    expect(find.text('On-device text generation'), findsOneWidget);
    expect(
      find.text('Needs more memory than this device has.'),
      findsOneWidget,
    );
    // The model picker / self-test are absent on low tier.
    expect(find.text('Test text generation'), findsNothing);
  });

  testWidgets('high tier shows the generation model picker, not the reason', (
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
          activeDeviceTierProvider.overrideWith(
            () => _FixedTier(DeviceTier.high),
          ),
        ],
        child: const MaterialApp(home: AiSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // High tier offers the model picker (the recommended Qwen3 rung), not the
    // "needs more memory" reason. (The self-test tile only appears once enabled.)
    expect(find.text('Needs more memory than this device has.'), findsNothing);
    expect(find.text('Qwen3 0.6B'), findsOneWidget);
  });

  testWidgets('low tier shows the multilingual disabled tile (P12 sweep)', (
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
          activeDeviceTierProvider.overrideWith(
            () => _FixedTier(DeviceTier.low),
          ),
        ],
        child: const MaterialApp(home: AiSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Multilingual is an upgrade over the always-present Gecko floor; on a low
    // device it's shown as a muted disabled tile (not hidden), like generation.
    expect(find.text('Multilingual semantic search'), findsOneWidget);
    expect(find.text('Available on more capable devices.'), findsOneWidget);
  });

  testWidgets(
    'high tier shows the multilingual switch, not the disabled tile',
    (tester) async {
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
            activeDeviceTierProvider.overrideWith(
              () => _FixedTier(DeviceTier.high),
            ),
          ],
          child: const MaterialApp(home: AiSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Available on more capable devices.'), findsNothing);
      // The real opt-in switch is present (a SwitchListTile titled the same).
      expect(find.byType(SwitchListTile), findsWidgets);
    },
  );

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

  testWidgets(
    'a downloaded model shows its state + delete affordance (P13f-1)',
    (tester) async {
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
            activeDeviceTierProvider.overrideWith(
              () => _FixedTier(DeviceTier.high),
            ),
            // The recommended generation model is cached but not active.
            downloadedModelIdsProvider.overrideWith(
              (ref) async => {qwen3_0_6b.id},
            ),
          ],
          child: const MaterialApp(home: AiSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Qwen3 0.6B'), findsOneWidget);
      // Its tile reads "Downloaded" (not "~MB") and offers a delete affordance.
      expect(find.textContaining('Downloaded'), findsWidgets);
      expect(find.byType(PopupMenuButton<void>), findsWidgets);
    },
  );
}
