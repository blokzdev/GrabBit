import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/data/settings_repository.dart';
import 'package:grabbit/features/settings/presentation/settings_screen.dart';

void main() {
  testWidgets('renders all settings sections', (tester) async {
    // Tall surface so the lazy ListView realizes every section header.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    for (final section in const [
      'Downloads',
      'Downloader engine',
      'Storage',
      'Appearance',
      'Security',
      'Privacy',
    ]) {
      expect(find.text(section), findsOneWidget);
    }
  });

  testWidgets('Block screenshots toggle persists (P9e)', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Auto-lock'), findsOneWidget);
    expect(find.text('Change PIN'), findsOneWidget);
    expect(find.text('After 1 minute'), findsOneWidget); // default 60s
  });

  testWidgets('toggling advanced mode persists to settings', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Advanced mode'), findsOneWidget);

    await tester.tap(find.text('Advanced mode'));
    await tester.pumpAndSettle();

    expect((await SettingsRepository(db).read()).mode, UiMode.advanced);
  });

  testWidgets('inserting a filename token persists and updates the preview', (
    tester,
  ) async {
    // Tall surface so the filename chips render below the new safety rows.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Default pattern preview.
    expect(find.textContaining('Preview:'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Channel'));
    await tester.pumpAndSettle();

    final saved = (await SettingsRepository(db).read()).filenameTemplate;
    expect(saved, '{title}{channel}');
    expect(find.textContaining('Rick Astley'), findsOneWidget);
  });

  testWidgets('Faster downloads (beta) toggle persists 4 fragments', (
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
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Faster downloads (beta)'));
    await tester.pumpAndSettle();

    expect((await SettingsRepository(db).read()).concurrentFragments, 4);
  });

  testWidgets('advanced download options appear only in advanced mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Seed advanced mode so the gated section renders.
    await SettingsRepository(
      db,
    ).write(const SettingsModel(mode: UiMode.advanced));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Advanced download options'), findsOneWidget);
    expect(find.text('Extra yt-dlp arguments'), findsOneWidget);
    expect(find.text('SponsorBlock'), findsOneWidget);
    expect(find.text('Split into chapters'), findsOneWidget);
  });

  testWidgets('subtitle detail rows appear when subtitles are enabled', (
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
    ).write(const SettingsModel(subtitleLangs: 'en'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Subtitle languages'), findsOneWidget);
    expect(find.text('Include auto-generated'), findsOneWidget);
    expect(find.text('Subtitle format'), findsOneWidget);
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
