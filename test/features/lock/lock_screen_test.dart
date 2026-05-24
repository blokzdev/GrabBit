import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/lock/lock_screen.dart';
import 'package:grabbit/features/lock/lockout_policy.dart';
import 'package:grabbit/features/lock/pin_repository.dart';

class _FakeStore implements SecureStore {
  final Map<String, String> _data = {};
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<void> delete(String key) async => _data.remove(key);
}

void main() {
  testWidgets(
    'shows the PIN field + Unlock and surfaces an error on a wrong PIN',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = PinRepository(_FakeStore());
      await repo.setPin('4321');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            pinRepositoryProvider.overrideWithValue(repo),
            lockoutPolicyProvider.overrideWithValue(
              LockoutPolicy(_FakeStore()),
            ),
          ],
          child: const MaterialApp(home: LockScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GrabBit is locked'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Unlock'), findsOneWidget);
      // Biometric is off by default → no biometrics action.
      expect(find.text('Use biometrics'), findsNothing);

      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect PIN'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
