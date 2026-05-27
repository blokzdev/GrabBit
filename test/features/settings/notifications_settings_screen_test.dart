import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/settings/data/settings_repository.dart';
import 'package:grabbit/features/settings/presentation/notifications_settings_screen.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget wrap() => ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: const MaterialApp(home: NotificationsSettingsScreen()),
  );

  testWidgets('toggling a category switch flips its setting', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Default is on.
    expect((await SettingsRepository(db).read()).notifyDownload, isTrue);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Download activity'));
    await tester.pumpAndSettle();

    expect((await SettingsRepository(db).read()).notifyDownload, isFalse);
  });

  testWidgets('changing retention updates the setting', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect((await SettingsRepository(db).read()).notificationRetentionDays, 30);

    await tester.tap(find.text('30 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 days').last);
    await tester.pumpAndSettle();

    expect((await SettingsRepository(db).read()).notificationRetentionDays, 7);
  });
}
