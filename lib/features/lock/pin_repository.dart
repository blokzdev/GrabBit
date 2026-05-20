import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key/value store so the PIN logic is unit-testable without a platform.
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore();
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Stores the app-lock PIN as a salted SHA-256 hash in secure storage. The plain
/// PIN is never persisted, and (unlike SPEC §4's nominal schema) neither the
/// hash nor salt live in the settings JSON — only `appLock.enabled/biometric` do.
class PinRepository {
  PinRepository(this._store);

  final SecureStore _store;
  static const _saltKey = 'lock_salt';
  static const _hashKey = 'lock_hash';

  Future<bool> isConfigured() async => await _store.read(_hashKey) != null;

  Future<void> setPin(String pin) async {
    final salt = _randomSalt();
    await _store.write(_saltKey, salt);
    await _store.write(_hashKey, _hash(salt, pin));
  }

  Future<bool> verify(String pin) async {
    final salt = await _store.read(_saltKey);
    final hash = await _store.read(_hashKey);
    if (salt == null || hash == null) return false;
    return _hash(salt, pin) == hash;
  }

  Future<void> clear() async {
    await _store.delete(_saltKey);
    await _store.delete(_hashKey);
  }

  String _randomSalt() {
    final rng = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => rng.nextInt(256)));
  }

  String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}

final pinRepositoryProvider = Provider<PinRepository>(
  (ref) => PinRepository(const FlutterSecureStore()),
);
