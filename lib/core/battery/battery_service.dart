import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Battery level + power-save state for the low-battery download guard (P9f).
/// [onChanged] lets the queue re-pump when charging state flips. A no-op
/// elsewhere / in tests reports a full, non-saving battery so it never blocks.
abstract class BatteryService {
  Future<int> level();
  Future<bool> isPowerSave();
  Stream<void> get onChanged;
}

class PlusBatteryService implements BatteryService {
  final Battery _battery = Battery();

  @override
  Future<int> level() => _battery.batteryLevel;

  @override
  Future<bool> isPowerSave() => _battery.isInBatterySaveMode;

  @override
  Stream<void> get onChanged => _battery.onBatteryStateChanged.map((_) {});
}

class NoopBatteryService implements BatteryService {
  @override
  Future<int> level() async => 100;

  @override
  Future<bool> isPowerSave() async => false;

  @override
  Stream<void> get onChanged => const Stream.empty();
}

final batteryServiceProvider = Provider<BatteryService>(
  (ref) => Platform.isAndroid ? PlusBatteryService() : NoopBatteryService(),
);
