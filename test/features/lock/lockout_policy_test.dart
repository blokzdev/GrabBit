import 'package:flutter_test/flutter_test.dart';
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

void main() {
  group('lockoutDuration', () {
    test('first four misses are free', () {
      for (var i = 0; i <= 4; i++) {
        expect(lockoutDuration(i), Duration.zero);
      }
    });

    test('escalates from the fifth miss and caps at 15 minutes', () {
      expect(lockoutDuration(5), const Duration(seconds: 30));
      expect(lockoutDuration(6), const Duration(minutes: 1));
      expect(lockoutDuration(7), const Duration(minutes: 5));
      expect(lockoutDuration(8), const Duration(minutes: 15));
      expect(lockoutDuration(99), const Duration(minutes: 15));
    });
  });

  group('LockoutPolicy', () {
    test('no cooldown before the threshold', () async {
      final p = LockoutPolicy(FakeStore());
      for (var i = 0; i < 4; i++) {
        await p.recordFailure();
      }
      expect(await p.remaining(), Duration.zero);
    });

    test('the fifth failure sets a future lock_until', () async {
      final p = LockoutPolicy(FakeStore());
      for (var i = 0; i < 5; i++) {
        await p.recordFailure();
      }
      final remaining = await p.remaining();
      expect(remaining, greaterThan(Duration.zero));
      expect(remaining, lessThanOrEqualTo(const Duration(seconds: 30)));
    });

    test('remaining counts down and reaches zero after the window', () async {
      final store = FakeStore();
      final p = LockoutPolicy(store);
      for (var i = 0; i < 5; i++) {
        await p.recordFailure();
      }
      final future = DateTime.now().add(const Duration(seconds: 31));
      expect(await p.remaining(future), Duration.zero);
    });

    test('recordSuccess clears the cooldown', () async {
      final p = LockoutPolicy(FakeStore());
      for (var i = 0; i < 5; i++) {
        await p.recordFailure();
      }
      await p.recordSuccess();
      expect(await p.remaining(), Duration.zero);
    });
  });
}
