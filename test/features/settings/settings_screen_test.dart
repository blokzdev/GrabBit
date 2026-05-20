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
}
