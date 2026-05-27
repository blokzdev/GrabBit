import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/notifications/data/notification_enums.dart';
import 'package:grabbit/features/notifications/data/notifications_repository.dart';
import 'package:grabbit/features/notifications/presentation/inbox_screen.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  // A static feed row for rendering (decoupled from the DB so no drift stream /
  // pending-timer is created in the widget tree).
  Notification feedRow(
    String id, {
    String title = 'T',
    String category = NotificationCategory.system,
    String? targetRoute,
    DateTime? createdAt,
  }) => Notification(
    id: id,
    category: category,
    severity: NotificationSeverity.info,
    title: title,
    targetRoute: targetRoute,
    createdAt: createdAt ?? DateTime.utc(2026),
    updatedAt: createdAt ?? DateTime.utc(2026),
    coalesceCount: 1,
  );

  // Inserts a real row so command side-effects (markAllRead / clear) are
  // observable in the DB.
  Future<void> seed(
    String id, {
    String category = NotificationCategory.system,
    String title = 'T',
    DateTime? readAt,
  }) => db
      .into(db.notifications)
      .insert(
        NotificationsCompanion.insert(
          id: id,
          category: category,
          severity: NotificationSeverity.info,
          title: title,
          readAt: Value(readAt),
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );

  Widget wrap(List<Notification> rows) => ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      notificationFeedByCategoryProvider.overrideWith(
        (ref, category) => Stream.value(
          category == null
              ? rows
              : rows.where((r) => r.category == category).toList(),
        ),
      ),
      unreadNotificationCountProvider.overrideWith((ref) => Stream.value(0)),
    ],
    child: const MaterialApp(home: InboxScreen()),
  );

  testWidgets('renders entries newest-first', (tester) async {
    await tester.pumpWidget(
      wrap([
        feedRow('b', title: 'Newer', createdAt: DateTime.utc(2026, 2)),
        feedRow('a', title: 'Older', createdAt: DateTime.utc(2026, 1)),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Newer'), findsOneWidget);
    expect(find.text('Older'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Newer')).dy,
      lessThan(tester.getTopLeft(find.text('Older')).dy),
    );
  });

  testWidgets('shows an empty state when there are no entries', (tester) async {
    await tester.pumpWidget(wrap(const []));
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets('wraps each row in a Dismissible for swipe-to-dismiss', (
    tester,
  ) async {
    await tester.pumpWidget(wrap([feedRow('a', title: 'Swipe me')]));
    await tester.pumpAndSettle();
    expect(find.byType(Dismissible), findsOneWidget);
  });

  testWidgets('a category chip narrows the feed', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrap([
        feedRow(
          'd',
          category: NotificationCategory.download,
          title: 'A download',
        ),
        feedRow('g', category: NotificationCategory.graph, title: 'A graph'),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Graph'));
    await tester.pumpAndSettle();

    expect(find.text('A graph'), findsOneWidget);
    expect(find.text('A download'), findsNothing);
  });

  testWidgets('opening the inbox marks everything read', (tester) async {
    await seed('a', title: 'Unread one');
    await seed('b', title: 'Unread two');

    await tester.pumpWidget(wrap(const []));
    await tester.pumpAndSettle();

    final rows = await db.select(db.notifications).get();
    expect(rows.every((r) => r.readAt != null), isTrue);
  });

  testWidgets('opening the inbox sweeps expired entries (P11c)', (
    tester,
  ) async {
    final past = DateTime.now().subtract(const Duration(days: 1));
    await db
        .into(db.notifications)
        .insert(
          NotificationsCompanion.insert(
            id: 'old',
            category: NotificationCategory.system,
            severity: NotificationSeverity.info,
            title: 'Expired',
            createdAt: past,
            updatedAt: past,
            expiresAt: Value(past),
          ),
        );

    await tester.pumpWidget(wrap(const []));
    await tester.pumpAndSettle();

    expect(await db.select(db.notifications).get(), isEmpty);
  });

  testWidgets('Clear all empties the feed after confirming', (tester) async {
    await seed('a', title: 'Doomed');
    await tester.pumpWidget(wrap([feedRow('a', title: 'Doomed')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    expect(await db.select(db.notifications).get(), isEmpty);
  });

  testWidgets('tapping an entry with a targetRoute deep-links', (tester) async {
    final router = GoRouter(
      initialLocation: '/inbox',
      routes: [
        GoRoute(path: '/inbox', builder: (_, _) => const InboxScreen()),
        GoRoute(
          path: '/item/x',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('Item screen'))),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificationFeedByCategoryProvider.overrideWith(
            (ref, category) => Stream.value([
              feedRow('a', title: 'Open me', targetRoute: '/item/x'),
            ]),
          ),
          unreadNotificationCountProvider.overrideWith(
            (ref) => Stream.value(0),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open me'));
    await tester.pumpAndSettle();

    expect(find.text('Item screen'), findsOneWidget);
  });
}
