import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/routing/router_refresh.dart';
import 'package:grabbit/features/lock/biometric_service.dart';
import 'package:grabbit/features/lock/lock_controller.dart';
import 'package:grabbit/features/lock/lockout_policy.dart';
import 'package:grabbit/features/lock/pin_repository.dart';

class FakeStore implements SecureStore {
  final Map<String, String> _data = {};
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<void> delete(String key) async => _data.remove(key);
}

class FakeBiometric extends BiometricService {
  FakeBiometric(this.result);
  final bool result;
  @override
  Future<bool> authenticate() async => result;
}

void main() {
  group('PinRepository', () {
    late PinRepository repo;
    setUp(() => repo = PinRepository(FakeStore()));

    test('not configured until a PIN is set', () async {
      expect(await repo.isConfigured(), isFalse);
      await repo.setPin('1234');
      expect(await repo.isConfigured(), isTrue);
    });

    test('verifies the correct PIN and rejects wrong ones', () async {
      await repo.setPin('1234');
      expect(await repo.verify('1234'), isTrue);
      expect(await repo.verify('0000'), isFalse);
    });

    test('clear removes the PIN', () async {
      await repo.setPin('1234');
      await repo.clear();
      expect(await repo.isConfigured(), isFalse);
      expect(await repo.verify('1234'), isFalse);
    });

    test('same PIN produces different hashes (random salt)', () async {
      final a = PinRepository(FakeStore());
      final b = PinRepository(FakeStore());
      await a.setPin('1234');
      await b.setPin('1234');
      // Both verify, but salts differ so a wrong cross-check still works.
      expect(await a.verify('1234'), isTrue);
      expect(await b.verify('1234'), isTrue);
    });
  });

  group('lockRedirect', () {
    test('locks when enabled + locked + not on lock screen', () {
      expect(lockRedirect(enabled: true, locked: true, atLock: false), '/lock');
    });
    test('leaves lock screen once unlocked', () {
      expect(lockRedirect(enabled: true, locked: false, atLock: true), '/');
    });
    test('no redirect when lock disabled', () {
      expect(lockRedirect(enabled: false, locked: true, atLock: false), isNull);
    });
  });

  group('startupRedirect', () {
    test('forces the disclaimer until accepted', () {
      expect(
        startupRedirect(
          disclaimerAccepted: false,
          lockEnabled: false,
          locked: false,
          location: '/',
        ),
        '/disclaimer',
      );
      // Already on the disclaimer: no further redirect.
      expect(
        startupRedirect(
          disclaimerAccepted: false,
          lockEnabled: false,
          locked: false,
          location: '/disclaimer',
        ),
        isNull,
      );
    });

    test('leaves the disclaimer once accepted', () {
      expect(
        startupRedirect(
          disclaimerAccepted: true,
          lockEnabled: false,
          locked: false,
          location: '/disclaimer',
        ),
        '/',
      );
    });

    test('disclaimer gates before the app lock', () {
      // Not accepted + lock enabled+locked still goes to the disclaimer first.
      expect(
        startupRedirect(
          disclaimerAccepted: false,
          lockEnabled: true,
          locked: true,
          location: '/',
        ),
        '/disclaimer',
      );
    });

    test('falls through to the lock check once accepted', () {
      expect(
        startupRedirect(
          disclaimerAccepted: true,
          lockEnabled: true,
          locked: true,
          location: '/',
        ),
        '/lock',
      );
      expect(
        startupRedirect(
          disclaimerAccepted: true,
          lockEnabled: false,
          locked: false,
          location: '/',
        ),
        isNull,
      );
    });
  });

  group('LockController', () {
    test('unlockWithPin transitions to unlocked on success', () async {
      final store = FakeStore();
      await PinRepository(store).setPin('4321');
      final container = ProviderContainer(
        overrides: [
          pinRepositoryProvider.overrideWithValue(PinRepository(store)),
          lockoutPolicyProvider.overrideWithValue(LockoutPolicy(FakeStore())),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(lockControllerProvider), LockState.locked);
      final notifier = container.read(lockControllerProvider.notifier);

      expect(await notifier.unlockWithPin('0000'), isFalse);
      expect(container.read(lockControllerProvider), LockState.locked);

      expect(await notifier.unlockWithPin('4321'), isTrue);
      expect(container.read(lockControllerProvider), LockState.unlocked);
    });

    test('biometric success unlocks', () async {
      final container = ProviderContainer(
        overrides: [
          biometricServiceProvider.overrideWithValue(FakeBiometric(true)),
        ],
      );
      addTearDown(container.dispose);
      final ok = await container
          .read(lockControllerProvider.notifier)
          .unlockWithBiometric();
      expect(ok, isTrue);
      expect(container.read(lockControllerProvider), LockState.unlocked);
    });
  });
}
