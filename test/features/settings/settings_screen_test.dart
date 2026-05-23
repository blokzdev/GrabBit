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
    ]) {
      expect(find.text(section), findsOneWidget);
    }
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
}
