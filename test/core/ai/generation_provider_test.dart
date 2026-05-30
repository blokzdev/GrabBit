import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/generation_model.dart';
import 'package:grabbit/core/ai/generation_provider.dart';
import 'package:grabbit/core/device/device_profile.dart';
import 'package:grabbit/core/device/device_tier_provider.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

class _FixedTier extends ActiveDeviceTier {
  _FixedTier(this._tier);
  final DeviceTier _tier;
  @override
  DeviceTier build() => _tier;
}

class _FixedSettings extends SettingsController {
  _FixedSettings(this._settings);
  final SettingsModel _settings;
  @override
  Future<SettingsModel> build() async => _settings;
}

ProviderContainer _container({
  required DeviceTier tier,
  required String selectedId,
}) {
  final container = ProviderContainer(
    overrides: [
      activeDeviceTierProvider.overrideWith(() => _FixedTier(tier)),
      settingsControllerProvider.overrideWith(
        () => _FixedSettings(
          SettingsModel(selectedGenerationModelId: selectedId),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('low tier has no active generation model (gated off)', () async {
    final container = _container(tier: DeviceTier.low, selectedId: '');
    await container.read(settingsControllerProvider.future);
    expect(container.read(activeGenerationModelProvider), isNull);
    // The engine is the graceful no-op fallback.
    expect(container.read(generationEngineProvider).isAvailable, isFalse);
  });

  test('an empty selection uses the tier recommendation', () async {
    final container = _container(tier: DeviceTier.high, selectedId: '');
    await container.read(settingsControllerProvider.future);
    expect(container.read(activeGenerationModelProvider), qwen3_0_6b);
  });

  test('an eligible selection wins over the recommendation', () async {
    final container = _container(
      tier: DeviceTier.high,
      selectedId: gemma4E2b.id,
    );
    await container.read(settingsControllerProvider.future);
    expect(container.read(activeGenerationModelProvider), gemma4E2b);
  });

  test(
    'an ineligible-for-tier selection falls back to the recommendation',
    () async {
      // The flagship isn't offered on mid tier → fall back to the mid rec.
      final container = _container(
        tier: DeviceTier.mid,
        selectedId: gemma4E2b.id,
      );
      await container.read(settingsControllerProvider.future);
      expect(container.read(activeGenerationModelProvider), qwen3_0_6b);
    },
  );

  test('an unknown selected id falls back to the recommendation', () async {
    final container = _container(tier: DeviceTier.high, selectedId: 'ghost');
    await container.read(settingsControllerProvider.future);
    expect(container.read(activeGenerationModelProvider), qwen3_0_6b);
  });

  test('generationEngine is never null and reports its model', () async {
    final container = _container(tier: DeviceTier.high, selectedId: '');
    await container.read(settingsControllerProvider.future);
    final engine = container.read(generationEngineProvider);
    // No native runtime on the CI host → Unavailable, but model still reported.
    expect(engine.isAvailable, isFalse);
    expect(engine.model, qwen3_0_6b);
  });
}
