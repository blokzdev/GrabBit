import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/device/device_profile.dart';

void main() {
  group('tierFor', () {
    DeviceProfile profile({int ramMb = 8000, int sdkInt = 34}) =>
        DeviceProfile(ramMb: ramMb, sdkInt: sdkInt);

    test('high tier for ample RAM on a modern OS', () {
      expect(tierFor(profile(ramMb: 8000)), DeviceTier.high);
      expect(
        tierFor(profile(ramMb: 6000)),
        DeviceTier.high,
      ); // boundary (>=6GB)
    });

    test('mid tier between the thresholds', () {
      expect(tierFor(profile(ramMb: 5999)), DeviceTier.mid);
      expect(tierFor(profile(ramMb: 3000)), DeviceTier.mid); // boundary (>=3GB)
    });

    test('low tier below the RAM floor', () {
      expect(tierFor(profile(ramMb: 2999)), DeviceTier.low);
      expect(tierFor(profile(ramMb: 0)), DeviceTier.low);
    });

    test('old OS floors to low regardless of RAM', () {
      expect(tierFor(profile(ramMb: 8000, sdkInt: 25)), DeviceTier.low);
      expect(tierFor(profile(ramMb: 8000, sdkInt: 26)), DeviceTier.high);
    });

    test('unknown/non-Android profile (zeros) is low', () {
      expect(tierFor(const DeviceProfile(ramMb: 0, sdkInt: 0)), DeviceTier.low);
    });
  });
}
