import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/data/settings_repository.dart';
import 'package:grabbit/features/settings/presentation/ai_settings_screen.dart';
import 'package:grabbit/features/settings/presentation/captions_settings_screen.dart';
import 'package:grabbit/features/settings/presentation/downloads_settings_screen.dart';
import 'package:grabbit/features/settings/presentation/settings_screen.dart';

Widget _wrap(AppDatabase db, {Widget home = const SettingsScreen()}) {
  return ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: MaterialApp(home: home),
  );
}

void main() {
  testWidgets('landing shows sub-screen links and inline sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    for (final label in const [
      // Sub-screen nav rows.
      'Downloads',
      'Captions & transcripts',
      'AI & graph',
      // Inline sections.
      'Downloader engine',
      'Storage',
      'Appearance',
      'Security',
      'Privacy',
      'General',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('nav rows open their sub-screens', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(
          path: '/settings/downloads',
          builder: (_, _) => const DownloadsSettingsScreen(),
        ),
        GoRoute(
          path: '/settings/captions',
          builder: (_, _) => const CaptionsSettingsScreen(),
        ),
        GoRoute(
          path: '/settings/ai',
          builder: (_, _) => const AiSettingsScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();
    expect(find.text('Max concurrent downloads'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Captions & transcripts'));
    await tester.pumpAndSettle();
    expect(find.text('Auto-fetch captions for transcripts'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI & graph'));
    await tester.pumpAndSettle();
    expect(find.text('Test embedder'), findsOneWidget);
  });

  testWidgets('app-bar overflow exposes maintenance actions', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Reset to defaults'), findsWidgets);
    expect(find.text('Clear cache'), findsWidgets);
    expect(find.text('About'), findsWidgets);
  });

  testWidgets('General section runs Reset to defaults', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await SettingsRepository(
      db,
    ).write(const SettingsModel(mode: UiMode.advanced));

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    // The General row (not the overflow) triggers the same confirm flow.
    await tester.tap(find.widgetWithText(ListTile, 'Reset to defaults'));
    await tester.pumpAndSettle();

    expect(find.text('Reset to defaults?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();

    expect((await SettingsRepository(db).read()).mode, UiMode.simple);
  });

  testWidgets('Pure black (AMOLED) toggle persists', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    expect(find.text('Pure black (AMOLED)'), findsOneWidget);
    await tester.tap(find.text('Pure black (AMOLED)'));
    await tester.pumpAndSettle();

    expect((await SettingsRepository(db).read()).amoledDark, isTrue);
  });

  testWidgets('Block screenshots toggle persists (P9e)', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Block screenshots'));
    await tester.pumpAndSettle();

    expect((await SettingsRepository(db).read()).blockScreenshots, isTrue);
  });

  testWidgets('Auto-lock and Change PIN appear only when app lock is on', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    // Lock off by default: no auto-lock / change-PIN rows.
    expect(find.text('Auto-lock'), findsNothing);
    expect(find.text('Change PIN'), findsNothing);
  });

  testWidgets('Auto-lock dropdown shows when app lock is enabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await SettingsRepository(
      db,
    ).write(const SettingsModel(appLock: AppLockSettings(enabled: true)));

    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    expect(find.text('Auto-lock'), findsOneWidget);
    expect(find.text('Change PIN'), findsOneWidget);
    expect(find.text('After 1 minute'), findsOneWidget); // default 60s
  });

  testWidgets('lays out without overflow at 200% text scale', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
