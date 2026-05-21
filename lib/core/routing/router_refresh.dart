import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/features/lock/lock_controller.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// Bridges Riverpod lock/settings state to go_router's [refreshListenable] so
/// the redirect re-evaluates when the lock state or app-lock setting changes.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(this._ref) {
    _ref.listen(lockControllerProvider, (_, _) => notifyListeners());
    _ref.listen(settingsControllerProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}

/// Pure app-lock redirect decision (extracted for testability).
String? lockRedirect({
  required bool enabled,
  required bool locked,
  required bool atLock,
}) {
  if (enabled && locked && !atLock) return '/lock';
  if ((!enabled || !locked) && atLock) return '/';
  return null;
}

/// Pure startup redirect: the one-time legal disclaimer gates everything, then
/// the app-lock check applies. Extracted for testability.
String? startupRedirect({
  required bool disclaimerAccepted,
  required bool lockEnabled,
  required bool locked,
  required String location,
}) {
  final atDisclaimer = location == '/disclaimer';
  if (!disclaimerAccepted) return atDisclaimer ? null : '/disclaimer';
  if (atDisclaimer) return '/';
  return lockRedirect(
    enabled: lockEnabled,
    locked: locked,
    atLock: location == '/lock',
  );
}
