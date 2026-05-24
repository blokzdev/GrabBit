import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/lock/auto_lock_controller.dart';
import 'package:grabbit/features/lock/lock_controller.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

ProviderContainer _container({required bool enabled, required int seconds}) {
  final container = ProviderContainer(
    overrides: [
      settingsControllerProvider.overrideWith(
        () => _FakeSettings(
          SettingsModel(
            appLock: AppLockSettings(
              enabled: enabled,
              autoLockSeconds: seconds,
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _FakeSettings extends SettingsController {
  _FakeSettings(this._value);
  final SettingsModel _value;
  @override
  Future<SettingsModel> build() async => _value;
}

void main() {
  test('locks immediately when autoLockSeconds is 0', () async {
    final container = _container(enabled: true, seconds: 0);
    await container.read(settingsControllerProvider.future);
    container.read(lockControllerProvider.notifier).unlock();

    container.read(autoLockProvider.notifier).appBackgrounded();
    expect(container.read(lockControllerProvider), LockState.locked);
  });

  test('locks only after the grace period', () {
    fakeAsync((async) {
      final container = _container(enabled: true, seconds: 60);
      container.read(settingsControllerProvider);
      async.flushMicrotasks(); // resolve the async settings build
      container.read(lockControllerProvider.notifier).unlock();

      container.read(autoLockProvider.notifier).appBackgrounded();
      async.elapse(const Duration(seconds: 59));
      expect(container.read(lockControllerProvider), LockState.unlocked);

      async.elapse(const Duration(seconds: 1));
      expect(container.read(lockControllerProvider), LockState.locked);
    });
  });

  test('returning before expiry stays unlocked', () {
    fakeAsync((async) {
      final container = _container(enabled: true, seconds: 60);
      container.read(settingsControllerProvider);
      async.flushMicrotasks();
      container.read(lockControllerProvider.notifier).unlock();

      final autoLock = container.read(autoLockProvider.notifier);
      autoLock.appBackgrounded();
      async.elapse(const Duration(seconds: 30));
      autoLock.appForegrounded();
      async.elapse(const Duration(minutes: 5));
      expect(container.read(lockControllerProvider), LockState.unlocked);
    });
  });

  test('does nothing when app lock is disabled', () async {
    final container = _container(enabled: false, seconds: 0);
    await container.read(settingsControllerProvider.future);
    container.read(lockControllerProvider.notifier).unlock();

    container.read(autoLockProvider.notifier).appBackgrounded();
    expect(container.read(lockControllerProvider), LockState.unlocked);
  });
}
