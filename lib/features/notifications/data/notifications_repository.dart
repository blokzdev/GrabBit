import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/notifications/data/notification_center.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// CRUD + streaming over the `notifications` table (P11 activity inbox).
/// All writes for new entries go through [NotificationCenter.post]; this layer
/// is the thin Drift access used by the seam and by the inbox UI commands.
class NotificationsRepository {
  NotificationsRepository(this._db);

  final AppDatabase _db;

  /// The inbox feed, newest first. Optionally filtered to a single category.
  Stream<List<Notification>> watchFeed({String? category}) {
    final query = _db.select(_db.notifications)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (category != null) {
      query.where((t) => t.category.equals(category));
    }
    return query.watch();
  }

  /// Live unread count for the app-bar badge.
  Stream<int> watchUnreadCount() {
    final count = _db.notifications.id.count();
    final query = _db.selectOnly(_db.notifications)
      ..addColumns([count])
      ..where(_db.notifications.readAt.isNull());
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Newest still-unexpired entry carrying [key], for dedupe coalescing.
  Future<Notification?> latestByDedupeKey(
    String key, {
    required DateTime now,
  }) =>
      (_db.select(_db.notifications)
            ..where(
              (t) =>
                  t.dedupeKey.equals(key) &
                  (t.expiresAt.isNull() | t.expiresAt.isBiggerThanValue(now)),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<void> insert(NotificationsCompanion row) =>
      _db.into(_db.notifications).insert(row);

  /// Folds a duplicate into an existing entry (resurfaces + resets read state).
  Future<void> coalesce(String id, NotificationsCompanion changes) =>
      (_db.update(
        _db.notifications,
      )..where((t) => t.id.equals(id))).write(changes);

  Future<void> markRead(String id) async {
    await (_db.update(_db.notifications)..where((t) => t.id.equals(id))).write(
      NotificationsCompanion(readAt: Value(DateTime.now())),
    );
  }

  Future<void> markAllRead() async {
    await (_db.update(_db.notifications)..where((t) => t.readAt.isNull()))
        .write(NotificationsCompanion(readAt: Value(DateTime.now())));
  }

  Future<void> dismiss(String id) async {
    await (_db.delete(_db.notifications)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes every entry, or only those in [category]. Returns the row count.
  Future<int> clear({String? category}) {
    final delete = _db.delete(_db.notifications);
    if (category != null) {
      delete.where((t) => t.category.equals(category));
    }
    return delete.go();
  }

  /// Lazy retention sweep: drops entries whose [expiresAt] has passed. Rows with
  /// a null `expiresAt` (retention 0 = forever) are never swept. Returns the
  /// deleted count. Safe to call redundantly and on an empty DB.
  Future<int> sweepExpired(DateTime now) {
    return (_db.delete(_db.notifications)..where(
          (t) =>
              t.expiresAt.isNotNull() & t.expiresAt.isSmallerOrEqualValue(now),
        ))
        .go();
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(appDatabaseProvider)),
);

final notificationCenterProvider = Provider<NotificationCenter>(
  (ref) => NotificationCenter(
    ref.watch(notificationsRepositoryProvider),
    () => ref.read(settingsControllerProvider.future),
  ),
);

/// The inbox feed (Drift row type ⇒ hand-written, per CLAUDE.md §8).
final notificationFeedProvider = StreamProvider<List<Notification>>(
  (ref) => ref.watch(notificationsRepositoryProvider).watchFeed(),
);

/// Category-filtered inbox feed (`null` = all categories).
final notificationFeedByCategoryProvider =
    StreamProvider.family<List<Notification>, String?>(
      (ref, category) => ref
          .watch(notificationsRepositoryProvider)
          .watchFeed(category: category),
    );

/// Unread count for the app-bar bell badge.
final unreadNotificationCountProvider = StreamProvider<int>(
  (ref) => ref.watch(notificationsRepositoryProvider).watchUnreadCount(),
);
