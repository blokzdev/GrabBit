import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/device/device_profile.dart';
import 'package:grabbit/core/engine/pigeon/engine.pigeon.dart';

/// Probes the device's AI-relevant hardware once → a [DeviceProfile] (P12a). A
/// no-op elsewhere / in tests reports a conservative (low-tier) profile so
/// capabilities never over-offer. Mirrors `BatteryService` / `DiskSpaceService`.
abstract class DeviceCapabilityService {
  Future<DeviceProfile> probe();
}

class AndroidDeviceCapabilityService implements DeviceCapabilityService {
  AndroidDeviceCapabilityService([DeviceHostApi? host])
    : _host = host ?? DeviceHostApi();

  final DeviceHostApi _host;

  @override
  Future<DeviceProfile> probe() async {
    final info = await _host.deviceInfo();
    return DeviceProfile(
      ramMb: info.totalRamMb,
      sdkInt: info.sdkInt,
      soc: info.soc,
      model: info.model,
    );
  }
}

/// Reports a conservative profile (→ [DeviceTier.low]) on non-Android hosts and
/// in tests, so nothing heavier than the universal floor is ever offered.
class NoopDeviceCapabilityService implements DeviceCapabilityService {
  const NoopDeviceCapabilityService();

  @override
  Future<DeviceProfile> probe() async =>
      const DeviceProfile(ramMb: 0, sdkInt: 0);
}

final deviceCapabilityServiceProvider = Provider<DeviceCapabilityService>(
  (ref) => Platform.isAndroid
      ? AndroidDeviceCapabilityService()
      : const NoopDeviceCapabilityService(),
);
