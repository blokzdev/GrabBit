import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/features/lock/pin_repository.dart';

/// Escalating cooldown after repeated wrong PINs (best-effort brute-force
/// resistance). The first four misses are free; from the fifth on, each adds a
/// longer wait, capped at 15 minutes.
Duration lockoutDuration(int failCount) => switch (failCount) {
  < 5 => Duration.zero,
  5 => const Duration(seconds: 30),
  6 => const Duration(minutes: 1),
  7 => const Duration(minutes: 5),
  _ => const Duration(minutes: 15),
};

/// Tracks failed PIN attempts in secure storage so a restart can't reset the
/// cooldown (P9e).
class LockoutPolicy {
  LockoutPolicy(this._store);

  final SecureStore _store;
  static const _countKey = 'lock_fail_count';
  static const _untilKey = 'lock_until';

  Future<void> recordFailure() async {
    final count = (int.tryParse(await _store.read(_countKey) ?? '') ?? 0) + 1;
    await _store.write(_countKey, '$count');
    final cooldown = lockoutDuration(count);
    if (cooldown > Duration.zero) {
      final until = DateTime.now().add(cooldown).millisecondsSinceEpoch;
      await _store.write(_untilKey, '$until');
    }
  }

  Future<void> recordSuccess() async {
    await _store.delete(_countKey);
    await _store.delete(_untilKey);
  }

  /// How long the user must still wait before trying again (zero if unlocked).
  Future<Duration> remaining([DateTime? now]) async {
    final raw = await _store.read(_untilKey);
    final until = raw == null ? null : int.tryParse(raw);
    if (until == null) return Duration.zero;
    final ms = until - (now ?? DateTime.now()).millisecondsSinceEpoch;
    return ms > 0 ? Duration(milliseconds: ms) : Duration.zero;
  }
}

final lockoutPolicyProvider = Provider<LockoutPolicy>(
  (ref) => LockoutPolicy(const FlutterSecureStore()),
);
