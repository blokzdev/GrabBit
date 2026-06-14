import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';

void main() {
  test('lastSeenCrashAt defaults to null and round-trips through JSON', () {
    expect(const SettingsModel().lastSeenCrashAt, isNull);

    final t = DateTime.utc(2026, 6, 14, 12, 30);
    final restored = SettingsModel.fromJson(
      const SettingsModel().copyWith(lastSeenCrashAt: t).toJson(),
    );
    expect(restored.lastSeenCrashAt, t);
  });
}
