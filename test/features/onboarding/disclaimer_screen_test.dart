import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/onboarding/presentation/disclaimer_screen.dart';
import 'package:grabbit/features/settings/data/settings_repository.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

void main() {
  testWidgets('shows the user-responsibility text and accepts it', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    // Hydrate settings before pumping.
    await container.read(settingsControllerProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DisclaimerScreen()),
      ),
    );

    expect(find.textContaining('responsible'), findsOneWidget);

    await tester.tap(find.text('I understand and agree'));
    await tester.pump();

    expect((await SettingsRepository(db).read()).disclaimerAccepted, isTrue);
  });
}
