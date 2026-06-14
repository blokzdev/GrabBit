import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/diagnostics/crash_log.dart';

/// The app's [CrashLog]. Defaults to a no-op ([CrashLog.disabled]) and is
/// **overridden in `main()`** with the real instance created before `runApp`
/// (so the error handlers and the UI share one instance). The disabled default
/// keeps tests / non-main contexts off disk.
final crashLogProvider = Provider<CrashLog>((ref) => CrashLog.disabled());

/// The last recorded crash, if any. One-shot read (FutureProvider — no streams),
/// so widget tests resolve to null with the disabled default and show no modal.
final pendingCrashReportProvider = FutureProvider<CrashReport?>(
  (ref) => ref.watch(crashLogProvider).readPending(),
);

/// Whether the next-launch crash modal should be shown: a crash exists and is
/// newer than the last one the user already saw. Pure + unit-testable.
bool shouldShowCrash(CrashReport? report, DateTime? lastSeen) {
  if (report == null) return false;
  return lastSeen == null || report.time.isAfter(lastSeen);
}
