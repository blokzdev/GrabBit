import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/notifications/data/notification_center.dart';
import 'package:grabbit/features/notifications/data/notification_enums.dart';
import 'package:grabbit/features/notifications/data/notifications_repository.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';

void main() {
  late AppDatabase db;
  late NotificationsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotificationsRepository(db);
  });
  tearDown(() => db.close());

  // A seam whose gating reads the given settings.
  NotificationCenter center(SettingsModel settings) =>
      NotificationCenter(repo, () async => settings);

  const allOff = SettingsModel(
    notifyDownload: false,
    notifyTranscript: false,
    notifyAi: false,
    notifyGraph: false,
  );

  test(
    'post records an unread entry with a 30-day expiry by default',
    () async {
      final id = await center(const SettingsModel()).post(
        category: NotificationCategory.download,
        severity: NotificationSeverity.success,
        title: 'Downloaded',
      );
      expect(id, isNotNull);

      final n = (await repo.watchFeed().first).single;
      expect(n.readAt, isNull);
      expect(n.coalesceCount, 1);
      expect(n.expiresAt, isNotNull);
      expect(n.expiresAt!.difference(n.createdAt).inDays, 30);
    },
  );

  test('dedupe coalesces onto the newest entry by key', () async {
    final c = center(const SettingsModel());
    final id1 = await c.post(
      category: NotificationCategory.graph,
      severity: NotificationSeverity.warning,
      title: 'Rebuild slow',
      dedupeKey: 'graph_rebuild',
    );
    final id2 = await c.post(
      category: NotificationCategory.graph,
      severity: NotificationSeverity.error,
      title: 'Rebuild failed',
      dedupeKey: 'graph_rebuild',
    );

    expect(id2, id1); // same row
    final n = (await repo.watchFeed().first).single;
    expect(n.coalesceCount, 2);
    expect(n.title, 'Rebuild failed');
    expect(n.severity, NotificationSeverity.error);
  });

  test('coalescing a read entry resurfaces it as unread', () async {
    final c = center(const SettingsModel());
    final id = await c.post(
      category: NotificationCategory.graph,
      severity: NotificationSeverity.info,
      title: 'A',
      dedupeKey: 'k',
    );
    await repo.markRead(id!);
    expect(await repo.watchUnreadCount().first, 0);

    await c.post(
      category: NotificationCategory.graph,
      severity: NotificationSeverity.info,
      title: 'A again',
      dedupeKey: 'k',
    );
    expect(await repo.watchUnreadCount().first, 1);
  });

  test('a disabled category is dropped — no row written', () async {
    final id = await center(allOff).post(
      category: NotificationCategory.download,
      severity: NotificationSeverity.info,
      title: 'x',
    );
    expect(id, isNull);
    expect(await repo.watchFeed().first, isEmpty);
  });

  test(
    'errors and system notices record even when categories are off',
    () async {
      final c = center(allOff);
      expect(
        await c.post(
          category: NotificationCategory.download,
          severity: NotificationSeverity.error,
          title: 'Download failed',
        ),
        isNotNull,
      );
      expect(
        await c.post(
          category: NotificationCategory.system,
          severity: NotificationSeverity.info,
          title: 'Engine updated',
        ),
        isNotNull,
      );
      expect(await repo.watchFeed().first, hasLength(2));
    },
  );

  test(
    'sweepExpired deletes only past-due rows, keeping future and forever',
    () async {
      final now = DateTime.utc(2026, 6, 1);
      Future<void> seed(String id, DateTime? expiresAt) => repo.insert(
        NotificationsCompanion.insert(
          id: id,
          category: NotificationCategory.system,
          severity: NotificationSeverity.info,
          title: id,
          createdAt: now,
          updatedAt: now,
          expiresAt: Value(expiresAt),
        ),
      );
      await seed('past', now.subtract(const Duration(days: 1)));
      await seed('future', now.add(const Duration(days: 1)));
      await seed('forever', null);

      final deleted = await repo.sweepExpired(now);
      expect(deleted, 1);
      final remaining = (await repo.watchFeed().first).map((n) => n.id).toSet();
      expect(remaining, {'future', 'forever'});
    },
  );

  test('retention 0 stores no expiry and survives any sweep', () async {
    await center(const SettingsModel(notificationRetentionDays: 0)).post(
      category: NotificationCategory.download,
      severity: NotificationSeverity.info,
      title: 'x',
    );
    final n = (await repo.watchFeed().first).single;
    expect(n.expiresAt, isNull);

    final deleted = await repo.sweepExpired(
      DateTime.now().add(const Duration(days: 365000)),
    );
    expect(deleted, 0);
  });

  test('mark read / mark all read drive the unread count', () async {
    final c = center(const SettingsModel());
    final id = await c.post(
      category: NotificationCategory.download,
      severity: NotificationSeverity.info,
      title: 'a',
    );
    await c.post(
      category: NotificationCategory.system,
      severity: NotificationSeverity.info,
      title: 'b',
    );
    expect(await repo.watchUnreadCount().first, 2);

    await repo.markRead(id!);
    expect(await repo.watchUnreadCount().first, 1);

    await repo.markAllRead();
    expect(await repo.watchUnreadCount().first, 0);
  });

  test(
    'dismiss removes one; clear(category) is scoped; clear empties',
    () async {
      final c = center(const SettingsModel());
      final id = await c.post(
        category: NotificationCategory.download,
        severity: NotificationSeverity.info,
        title: 'a',
      );
      await c.post(
        category: NotificationCategory.graph,
        severity: NotificationSeverity.info,
        title: 'b',
      );

      await repo.dismiss(id!);
      expect(await repo.watchFeed().first, hasLength(1));

      await c.post(
        category: NotificationCategory.download,
        severity: NotificationSeverity.info,
        title: 'c',
      );
      final removed = await repo.clear(category: NotificationCategory.graph);
      expect(removed, 1);
      expect(
        (await repo.watchFeed().first).every(
          (n) => n.category == NotificationCategory.download,
        ),
        isTrue,
      );

      await repo.clear();
      expect(await repo.watchFeed().first, isEmpty);
    },
  );

  test('feed can be filtered by category, newest first', () async {
    final c = center(const SettingsModel());
    await c.post(
      category: NotificationCategory.download,
      severity: NotificationSeverity.info,
      title: 'dl1',
    );
    await c.post(
      category: NotificationCategory.graph,
      severity: NotificationSeverity.info,
      title: 'g1',
    );

    final graphOnly = await repo
        .watchFeed(category: NotificationCategory.graph)
        .first;
    expect(graphOnly, hasLength(1));
    expect(graphOnly.single.title, 'g1');
  });
}
