import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/device/device_capability_service.dart';
import 'package:grabbit/core/device/device_profile.dart';
import 'package:grabbit/core/engine/pigeon/engine.pigeon.dart';

/// Overrides the Pigeon host's `deviceInfo()` so the mapping is testable without
/// a platform channel (the generated method isn't final).
class _FakeDeviceHostApi extends DeviceHostApi {
  _FakeDeviceHostApi(this._info);
  final DeviceInfoDto _info;
  @override
  Future<DeviceInfoDto> deviceInfo() async => _info;
}

void main() {
  test(
    'AndroidDeviceCapabilityService maps the host DTO to a DeviceProfile',
    () async {
      final service = AndroidDeviceCapabilityService(
        _FakeDeviceHostApi(
          DeviceInfoDto(
            totalRamMb: 6144,
            sdkInt: 34,
            soc: 'Tensor G3',
            model: 'Pixel 8',
          ),
        ),
      );

      final profile = await service.probe();

      expect(profile.ramMb, 6144);
      expect(profile.sdkInt, 34);
      expect(profile.soc, 'Tensor G3');
      expect(profile.model, 'Pixel 8');
      expect(tierFor(profile), DeviceTier.high);
    },
  );

  test(
    'NoopDeviceCapabilityService reports a conservative low-tier profile',
    () async {
      final profile = await const NoopDeviceCapabilityService().probe();
      expect(tierFor(profile), DeviceTier.low);
    },
  );
}
