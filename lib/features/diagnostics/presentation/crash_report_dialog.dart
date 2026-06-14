import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/diagnostics/crash_log.dart';
import 'package:grabbit/core/diagnostics/crash_log_providers.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// Shows the previous crash's report in a copyable dialog. On-device only —
/// nothing is sent anywhere; the user copies and shares manually.
Future<void> showCrashReportDialog(BuildContext context, CrashReport report) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final tokens = GrabBitTokens.of(context);
      return AlertDialog(
        icon: const Icon(Icons.bug_report_outlined),
        title: const Text('GrabBit closed unexpectedly'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A crash was recorded last time. Copy the details to share when '
                'reporting the issue — nothing is sent automatically.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: tokens.spaceMd),
              Flexible(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(tokens.spaceSm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      report.text,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: report.text));
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text('Crash log copied')),
                );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      );
    },
  );
}

/// Wraps the unlocked app shell and, once after the first frame, surfaces the
/// previous crash (if any, newer than the last one seen) in [showCrashReportDialog].
/// Placed inside the shell so it appears **behind the app lock** (the router gates
/// `/lock` first) and only for the authenticated user.
class CrashNoticeGate extends ConsumerStatefulWidget {
  const CrashNoticeGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CrashNoticeGate> createState() => _CrashNoticeGateState();
}

class _CrashNoticeGateState extends ConsumerState<CrashNoticeGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (_checked) return;
    _checked = true;
    final report = await ref.read(pendingCrashReportProvider.future);
    final settings = await ref.read(settingsControllerProvider.future);
    if (!shouldShowCrash(report, settings.lastSeenCrashAt)) return;
    // Mark seen *before* showing so a re-entrant frame / a crash while the dialog
    // is up can't loop on the same report; the file is kept for the About view.
    await ref
        .read(settingsControllerProvider.notifier)
        .markCrashSeen(report!.time);
    if (!mounted) return;
    await showCrashReportDialog(context, report);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
