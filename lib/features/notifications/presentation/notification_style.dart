import 'package:flutter/material.dart';
import 'package:grabbit/features/notifications/data/notification_enums.dart';

/// Container/on-container colors + glyph for an activity-inbox severity, shared
/// by the inbox tiles and the Dashboard recent-activity tile so they never
/// diverge. Mirrors the queue's `_statusStyle` convention.
({Color bg, Color fg, IconData icon}) severityStyle(
  ColorScheme s,
  String severity,
) => switch (severity) {
  NotificationSeverity.success => (
    bg: s.tertiaryContainer,
    fg: s.onTertiaryContainer,
    icon: Icons.check_circle_outline,
  ),
  NotificationSeverity.warning => (
    bg: s.secondaryContainer,
    fg: s.onSecondaryContainer,
    icon: Icons.warning_amber_outlined,
  ),
  NotificationSeverity.error => (
    bg: s.errorContainer,
    fg: s.onErrorContainer,
    icon: Icons.error_outline,
  ),
  _ => (
    bg: s.primaryContainer,
    fg: s.onPrimaryContainer,
    icon: Icons.info_outline,
  ),
};

IconData categoryIcon(String category) => switch (category) {
  NotificationCategory.download => Icons.download_outlined,
  NotificationCategory.transcript => Icons.closed_caption_outlined,
  NotificationCategory.ai => Icons.auto_awesome_outlined,
  NotificationCategory.graph => Icons.hub_outlined,
  NotificationCategory.reminder => Icons.alarm_outlined,
  _ => Icons.notifications_outlined,
};

String categoryLabel(String category) => switch (category) {
  NotificationCategory.download => 'Downloads',
  NotificationCategory.transcript => 'Transcripts',
  NotificationCategory.ai => 'AI',
  NotificationCategory.graph => 'Graph',
  NotificationCategory.system => 'System',
  NotificationCategory.reminder => 'Reminders',
  _ => category,
};

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Compact "just now / 5m / 3h / 2d / Mar 4" stamp for an inbox row.
String relativeTime(DateTime when, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final d = ref.difference(when);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${_months[when.month - 1]} ${when.day}';
}
