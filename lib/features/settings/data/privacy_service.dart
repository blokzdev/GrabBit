import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/engine/pigeon/engine.pigeon.dart';

/// Toggles the Android `FLAG_SECURE` window flag (block screenshots + hide the
/// recent-apps preview). A no-op elsewhere / in tests so callers stay
/// platform-agnostic.
abstract class PrivacyService {
  Future<void> setSecureFlag(bool enabled);
}

class NoopPrivacyService implements PrivacyService {
  @override
  Future<void> setSecureFlag(bool enabled) async {}
}

class AndroidPrivacyService implements PrivacyService {
  final PrivacyHostApi _host = PrivacyHostApi();

  @override
  Future<void> setSecureFlag(bool enabled) => _host.setSecureFlag(enabled);
}

final privacyServiceProvider = Provider<PrivacyService>(
  (ref) => Platform.isAndroid ? AndroidPrivacyService() : NoopPrivacyService(),
);
