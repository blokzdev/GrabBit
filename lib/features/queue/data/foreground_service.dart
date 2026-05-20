import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/engine/pigeon/engine.pigeon.dart';
import 'package:permission_handler/permission_handler.dart';

/// Controls the Android download foreground service. A no-op elsewhere / in
/// tests so the queue controller stays platform-agnostic.
abstract class ForegroundService {
  set onStop(void Function() callback);
  Future<void> start(
    String text, {
    int progress = 0,
    bool indeterminate = true,
  });
  Future<void> update(
    String text, {
    int progress = 0,
    bool indeterminate = false,
  });
  Future<void> stop();
  Future<bool> isUnmetered();
}

class NoopForegroundService implements ForegroundService {
  @override
  set onStop(void Function() callback) {}
  @override
  Future<void> start(
    String text, {
    int progress = 0,
    bool indeterminate = true,
  }) async {}
  @override
  Future<void> update(
    String text, {
    int progress = 0,
    bool indeterminate = false,
  }) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<bool> isUnmetered() async => true;
}

class AndroidForegroundService implements ForegroundService, ServiceFlutterApi {
  AndroidForegroundService() {
    ServiceFlutterApi.setUp(this);
  }

  final ServiceHostApi _host = ServiceHostApi();
  void Function()? _onStop;
  bool _notificationPermissionRequested = false;

  @override
  set onStop(void Function() callback) => _onStop = callback;

  @override
  Future<void> start(
    String text, {
    int progress = 0,
    bool indeterminate = true,
  }) async {
    if (!_notificationPermissionRequested) {
      _notificationPermissionRequested = true;
      await Permission.notification.request();
    }
    await _host.startService(text, progress, indeterminate);
  }

  @override
  Future<void> update(
    String text, {
    int progress = 0,
    bool indeterminate = false,
  }) => _host.updateNotification(text, progress, indeterminate);

  @override
  Future<void> stop() => _host.stopService();

  @override
  Future<bool> isUnmetered() => _host.isUnmetered();

  @override
  void onStopRequested() => _onStop?.call();
}

final foregroundServiceProvider = Provider<ForegroundService>(
  (ref) =>
      Platform.isAndroid ? AndroidForegroundService() : NoopForegroundService(),
);
