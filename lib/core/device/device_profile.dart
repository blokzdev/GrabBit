/// A snapshot of the device's AI-relevant hardware, probed once at startup, plus
/// the capability [DeviceTier] derived from it (P12a). RAM is the primary signal
/// for on-device LLMs; `hasNpu`/`hasGpu` are intentionally omitted — reliable
/// detection is hard and unnecessary for RAM-driven tiering (deferred; see
/// `docs/BACKLOG.md`).
class DeviceProfile {
  const DeviceProfile({
    required this.ramMb,
    required this.sdkInt,
    this.soc,
    this.model,
  });

  /// Total physical RAM in MB (`ActivityManager.MemoryInfo.totalMem`). Note this
  /// under-reports nominal RAM by the kernel reservation — a "4 GB" device reports
  /// ~3.6 GB — so [tierFor]'s thresholds account for it.
  final int ramMb;

  /// Android API level (`Build.VERSION.SDK_INT`); 0 when unknown (non-Android).
  final int sdkInt;

  /// SoC/hardware identifier (`Build.SOC_MODEL` on API 31+, else `Build.HARDWARE`).
  final String? soc;

  /// Marketing model name (`Build.MODEL`), for diagnostics/logging only.
  final String? model;

  @override
  String toString() =>
      'DeviceProfile(ramMb: $ramMb, sdkInt: $sdkInt, soc: $soc, model: $model)';
}

/// Coarse device capability band gating which on-device AI models are offered
/// (P12). Ordered low → high.
enum DeviceTier { low, mid, high }

/// User-facing copy for a [DeviceTier] (P12g) — the single source of tier wording,
/// shown in the AI-settings banner and first-run onboarding so capability-gating
/// is legible (a user on a basic device sees *why* fewer AI options appear).
/// Deliberately non-judgmental (no "low/weak"); never names the RAM threshold.
extension DeviceTierCopy on DeviceTier {
  /// Short, friendly band name.
  String get label => switch (this) {
    DeviceTier.low => 'Basic',
    DeviceTier.mid => 'Standard',
    DeviceTier.high => 'Advanced',
  };

  /// One line describing what on-device AI this tier runs.
  String get blurb => switch (this) {
    DeviceTier.low =>
      'Runs on-device semantic search and speech transcription.',
    DeviceTier.mid =>
      'Runs semantic search, transcription, and on-device text generation.',
    DeviceTier.high =>
      'Runs every on-device AI feature, including the largest, fastest models.',
  };
}

/// Derives the [DeviceTier] from a [DeviceProfile]. **RAM-primary**, with a hard
/// floor on very old OS versions. Thresholds are deliberately conservative and
/// tunable (validated on-device).
DeviceTier tierFor(DeviceProfile p) {
  // Android 8 (API 26) is the practical floor for the modern on-device runtimes.
  if (p.sdkInt < 26 || p.ramMb < 3000) return DeviceTier.low;
  if (p.ramMb < 6000) return DeviceTier.mid;
  return DeviceTier.high;
}
