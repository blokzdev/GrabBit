import 'package:grabbit/features/lock/biometric_service.dart';
import 'package:grabbit/features/lock/pin_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'lock_controller.g.dart';

enum LockState { locked, unlocked }

/// Tracks whether the app is currently locked. Starts locked; the router
/// redirect only enforces it when `appLock.enabled` is set in settings.
@Riverpod(keepAlive: true)
class LockController extends _$LockController {
  @override
  LockState build() => LockState.locked;

  void lock() => state = LockState.locked;
  void unlock() => state = LockState.unlocked;

  Future<bool> unlockWithPin(String pin) async {
    final ok = await ref.read(pinRepositoryProvider).verify(pin);
    if (ok) state = LockState.unlocked;
    return ok;
  }

  Future<bool> unlockWithBiometric() async {
    final ok = await ref.read(biometricServiceProvider).authenticate();
    if (ok) state = LockState.unlocked;
    return ok;
  }
}
