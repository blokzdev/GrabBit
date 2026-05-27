/// String constants for the activity-inbox `category` and `severity` columns
/// (P11). Stored as text in the `notifications` table; centralized here to keep
/// producers and the gating logic free of magic strings (mirrors `TaskStatus`).
abstract final class NotificationCategory {
  static const download = 'download';
  static const transcript = 'transcript';
  static const ai = 'ai';
  static const graph = 'graph';
  static const system = 'system';
  static const reminder = 'reminder';
}

abstract final class NotificationSeverity {
  static const info = 'info';
  static const success = 'success';
  static const warning = 'warning';
  static const error = 'error';
}
