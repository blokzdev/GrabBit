import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/data/settings_repository.dart';
import 'package:grabbit/features/settings/presentation/downloads_settings_screen.dart';

Future<void> _pump(WidgetTester tester, AppDatabase db) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: DownloadsSettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('toggling advanced mode persists to settings', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _pump(tester, db);

    expect(find.text('Advanced mode'), findsOneWidget);
    await tester.tap(find.text('Advanced mode'));
    await tester.pumpAndSettle();

    expect((await SettingsRepository(db).read()).mode, UiMode.advanced);
  });

  testWidgets('Faster downloads (beta) toggle persists 4 fragments', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _pump(tester, db);

    await tester.tap(find.text('Faster downloads (beta)'));
    await tester.pumpAndSettle();

    expect((await SettingsRepository(db).read()).concurrentFragments, 4);
  });

  testWidgets('inserting a filename token persists and updates the preview', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _pump(tester, db);

    expect(find.textContaining('Preview:'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'Channel'));
    await tester.pumpAndSettle();

    final saved = (await SettingsRepository(db).read()).filenameTemplate;
    expect(saved, '{title}{channel}');
    expect(find.textContaining('Rick Astley'), findsOneWidget);
  });

  testWidgets('advanced download options appear only in advanced mode', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await SettingsRepository(
      db,
    ).write(const SettingsModel(mode: UiMode.advanced));
    await _pump(tester, db);

    expect(find.text('Advanced download options'), findsOneWidget);
    expect(find.text('Extra yt-dlp arguments'), findsOneWidget);
    expect(find.text('SponsorBlock'), findsOneWidget);
    expect(find.text('Split into chapters'), findsOneWidget);
  });
}
