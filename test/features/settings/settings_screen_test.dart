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

  testWidgets('app-bar overflow exposes maintenance actions', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Reset to defaults'), findsOneWidget);
    expect(find.text('Clear cache'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('Reset to defaults confirms then restores prefs', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
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

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset to defaults'));
    await tester.pumpAndSettle();

    // Confirmation dialog, then confirm.
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
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

  testWidgets('Captions & transcripts unifies caption + transcript controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Captions on, transcript auto-build OFF — proves backfill is independent.
    await SettingsRepository(
      db,
    ).write(const SettingsModel(subtitleLangs: 'en', autoTranscribe: false));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // One section now holds both groups.
    expect(find.text('Captions & transcripts'), findsOneWidget);
    expect(find.text('Transcripts'), findsNothing);

    // Caption group (master on → detail rows visible, with new vocabulary).
    expect(find.text('Download captions'), findsOneWidget);
    expect(find.text('Caption languages'), findsOneWidget);
    expect(find.text('Include auto-generated'), findsOneWidget);
    expect(find.text('Caption format'), findsOneWidget);

    // Transcript group — backfill shows even though auto-build is off.
    expect(find.text('Build a searchable transcript'), findsOneWidget);
    expect(find.text('Backfill on open'), findsOneWidget);
    expect(find.text('Auto-fetch captions for transcripts'), findsOneWidget);
  });

  testWidgets('toggling Download captions persists subtitle langs', (
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

    expect((await SettingsRepository(db).read()).subtitleLangs, '');
    await tester.tap(find.text('Download captions'));
    await tester.pumpAndSettle();
    expect((await SettingsRepository(db).read()).subtitleLangs, 'en');
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
