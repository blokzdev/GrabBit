import 'dart:async';

import 'package:grabbit/features/lock/lock_controller.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auto_lock_controller.g.dart';

/// Re-locks the app after a user-chosen grace period in the background (P9e).
/// Driven by the app-lifecycle observer in `app.dart`: `appBackgrounded` arms a
/// timer, `appForegrounded` cancels it (so a quick return stays unlocked).
@Riverpod(keepAlive: true)
class AutoLock extends _$AutoLock {
  Timer? _timer;

  @override
  void build() {
    ref.onDispose(() => _timer?.cancel());
  }

  void appBackgrounded() {
    final settings = ref.read(settingsControllerProvider).asData?.value;
    if (settings == null || !settings.appLock.enabled) return;
    _timer?.cancel();
    final seconds = settings.appLock.autoLockSeconds;
    if (seconds <= 0) {
      ref.read(lockControllerProvider.notifier).lock();
      return;
    }
    _timer = Timer(
      Duration(seconds: seconds),
      () => ref.read(lockControllerProvider.notifier).lock(),
    );
  }

  void appForegrounded() {
    _timer?.cancel();
    _timer = null;
  }
}
