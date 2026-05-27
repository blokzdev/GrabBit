import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/recent_activity_tile.dart';
import 'package:grabbit/features/notifications/data/notification_enums.dart';
import 'package:grabbit/features/notifications/data/notifications_repository.dart';

Notification _row(String id, String title) => Notification(
  id: id,
  category: NotificationCategory.download,
  severity: NotificationSeverity.success,
  title: title,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  coalesceCount: 1,
);

Widget _wrap(List<Notification> rows) => ProviderScope(
  overrides: [
    notificationFeedProvider.overrideWith((ref) => Stream.value(rows)),
  ],
  child: const MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: RecentActivityTile())),
  ),
);

void main() {
  testWidgets('is hidden when the feed is empty', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pump();
    expect(find.text('Recent activity'), findsNothing);
  });

  testWidgets('shows recent entries and a See all link', (tester) async {
    await tester.pumpWidget(_wrap([_row('a', 'Saved a video')]));
    await tester.pump();
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.text('Saved a video'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
  });
}
