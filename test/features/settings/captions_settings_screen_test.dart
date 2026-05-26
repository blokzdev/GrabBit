import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/data/settings_repository.dart';
import 'package:grabbit/features/settings/presentation/captions_settings_screen.dart';

Future<void> _pump(WidgetTester tester, AppDatabase db) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: CaptionsSettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the caption + transcript pipeline', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Captions on, auto-build OFF — proves backfill is shown independently.
    await SettingsRepository(
      db,
    ).write(const SettingsModel(subtitleLangs: 'en', autoTranscribe: false));
    await _pump(tester, db);

    // Caption group (master on → detail rows visible).
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
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _pump(tester, db);

    expect((await SettingsRepository(db).read()).subtitleLangs, '');
    await tester.tap(find.text('Download captions'));
    await tester.pumpAndSettle();
    expect((await SettingsRepository(db).read()).subtitleLangs, 'en');
  });
}
