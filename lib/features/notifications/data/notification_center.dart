import 'package:drift/drift.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/utils/notification_id.dart';
import 'package:grabbit/features/notifications/data/notification_enums.dart';
import 'package:grabbit/features/notifications/data/notifications_repository.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';

/// The single write seam for the activity inbox (P11). Every feature posts
/// through [post]; no producer touches the `notifications` table directly.
///
/// Two policies live here so they stay consistent across all producers:
/// - **Category gating:** a category whose notify-toggle is off is dropped
///   entirely (no row written) — except `error` severity and the `system`/
///   `reminder` categories, which are always recorded.
/// - **Dedupe:** entries sharing a [dedupeKey] collapse onto the newest
///   unexpired one, resurfacing it to the top and re-marking it unread.
class NotificationCenter {
  NotificationCenter(this._repo, this._readSettings);

  final NotificationsRepository _repo;
  final Future<SettingsModel> Function() _readSettings;

  /// Records an activity-inbox entry. Returns the row id, or `null` when the
  /// category is gated off (nothing is written).
  Future<String?> post({
    required String category,
    required String severity,
    required String title,
    String? body,
    String? targetRoute,
    String? itemId,
    String? taskId,
    String? dedupeKey,
  }) async {
    final settings = await _readSettings();

    if (!_alwaysRecord(category, severity) &&
        !_categoryEnabled(category, settings)) {
      return null;
    }

    final now = DateTime.now();
    final retentionDays = settings.notificationRetentionDays;
    final expiresAt = retentionDays <= 0
        ? null
        : now.add(Duration(days: retentionDays));

    if (dedupeKey != null) {
      final existing = await _repo.latestByDedupeKey(dedupeKey, now: now);
      if (existing != null) {
        await _repo.coalesce(
          existing.id,
          NotificationsCompanion(
            title: Value(title),
            body: Value(body),
            severity: Value(severity),
            targetRoute: Value(targetRoute),
            createdAt: Value(now),
            updatedAt: Value(now),
            readAt: const Value(null),
            expiresAt: Value(expiresAt),
            coalesceCount: Value(existing.coalesceCount + 1),
          ),
        );
        return existing.id;
      }
    }

    final id = newNotificationId();
    await _repo.insert(
      NotificationsCompanion.insert(
        id: id,
        category: category,
        severity: severity,
        title: title,
        body: Value(body),
        targetRoute: Value(targetRoute),
        itemId: Value(itemId),
        taskId: Value(taskId),
        dedupeKey: Value(dedupeKey),
        createdAt: now,
        updatedAt: now,
        expiresAt: Value(expiresAt),
      ),
    );
    return id;
  }

  /// Errors and system/reminder notices are never gated — the user must always
  /// see failures, and reminders have no toggle yet.
  bool _alwaysRecord(String category, String severity) =>
      severity == NotificationSeverity.error ||
      category == NotificationCategory.system ||
      category == NotificationCategory.reminder;

  bool _categoryEnabled(String category, SettingsModel s) => switch (category) {
    NotificationCategory.download => s.notifyDownload,
    NotificationCategory.transcript => s.notifyTranscript,
    NotificationCategory.ai => s.notifyAi,
    NotificationCategory.graph => s.notifyGraph,
    _ => true,
  };
}
