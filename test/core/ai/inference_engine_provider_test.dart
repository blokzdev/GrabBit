import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/inference_engine_provider.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/device/device_profile.dart';
import 'package:grabbit/core/device/device_tier_provider.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// A fixed device tier for resolution tests.
class _FixedTier extends ActiveDeviceTier {
  _FixedTier(this._tier);
  final DeviceTier _tier;
  @override
  DeviceTier build() => _tier;
}

/// Serves a fixed settings snapshot (no DB) for resolution tests.
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
        () =>
            _FixedSettings(SettingsModel(selectedEmbedderModelId: selectedId)),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('an empty selection keeps the tier default (Gecko)', () async {
    final container = _container(tier: DeviceTier.high, selectedId: '');
    await container.read(settingsControllerProvider.future);
    expect(container.read(activeEmbedderModelProvider), geckoEmbedder);
  });

  test('an unknown selected id falls back to Gecko', () async {
    final container = _container(tier: DeviceTier.high, selectedId: 'ghost');
    await container.read(settingsControllerProvider.future);
    expect(container.read(activeEmbedderModelProvider), geckoEmbedder);
  });

  test('a low-tier device never resolves the multilingual model', () async {
    final container = _container(
      tier: DeviceTier.low,
      selectedId: paraphraseMultilingualMiniLmL12V2.id,
    );
    await container.read(settingsControllerProvider.future);
    // Ineligible at low tier → Gecko fallback regardless of platform.
    expect(container.read(activeEmbedderModelProvider), geckoEmbedder);
  });

  test('selecting MiniLM on a capable device resolves by platform', () async {
    final container = _container(
      tier: DeviceTier.high,
      selectedId: paraphraseMultilingualMiniLmL12V2.id,
    );
    await container.read(settingsControllerProvider.future);
    final resolved = container.read(activeEmbedderModelProvider);
    if (Platform.isAndroid) {
      // Eligible + runtime available → the override wins.
      expect(resolved, paraphraseMultilingualMiniLmL12V2);
    } else {
      // onnx can't run off-Android → graceful Gecko fallback (CI host path).
      expect(resolved, geckoEmbedder);
    }
  });
}
