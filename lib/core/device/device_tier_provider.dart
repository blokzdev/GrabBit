import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:grabbit/core/device/device_capability_service.dart';
import 'package:grabbit/core/device/device_profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_tier_provider.g.dart';

/// The device's capability [DeviceTier]. Returns a conservative [DeviceTier.low]
/// synchronously — so embedder/model selection stays sync, with no async ripple
/// through the engine providers — then probes the hardware once and updates to
/// the real tier. This tier drives every gated AI capability's model selection:
/// the embedder (Gecko vs multilingual MiniLM), generation, and transcription
/// (P12c–P12e), plus the capability-gating UX (P12g).
@Riverpod(keepAlive: true)
class ActiveDeviceTier extends _$ActiveDeviceTier {
  @override
  DeviceTier build() {
    unawaited(_probe());
    return DeviceTier.low;
  }

  Future<void> _probe() async {
    try {
      final profile = await ref.read(deviceCapabilityServiceProvider).probe();
      final tier = tierFor(profile);
      if (kDebugMode) {
        debugPrint('[P12a] device tier: $tier  ($profile)');
      }
      state = tier;
    } catch (_) {
      // Probe failure → keep the conservative default; AI stays gated low.
    }
  }
}
