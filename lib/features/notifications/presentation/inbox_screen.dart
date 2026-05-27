import 'dart:async';

import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/async_fade.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/notifications/data/notification_enums.dart';
import 'package:grabbit/features/notifications/data/notifications_repository.dart';
import 'package:grabbit/features/notifications/presentation/notification_style.dart';

/// `/inbox` — the Activity Inbox feed (P11b). Newest-first list of background
/// activity, filterable by category, swipe-to-dismiss, with a Clear-all action.
/// Opening the screen marks everything read so the app-bar bell badge clears.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  String? _category;

  // The filter chips: "All" plus the categories a user-facing producer posts to.
  static const _filters = <String?>[
    null,
    NotificationCategory.download,
    NotificationCategory.transcript,
    NotificationCategory.ai,
    NotificationCategory.graph,
    NotificationCategory.system,
  ];

  @override
  void initState() {
    super.initState();
    // Opening the inbox counts as seeing it: clear unread (and the bell badge).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(notificationsRepositoryProvider).markAllRead());
    });
  }

  Future<void> _clearAll() async {
    final ok = await confirm(
      context,
      title: 'Clear all activity?',
      message: 'This removes every notification. It cannot be undone.',
      confirmLabel: 'Clear all',
      destructive: true,
    );
    if (!ok) return;
    final count = await ref.read(notificationsRepositoryProvider).clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Cleared $count notification${count == 1 ? '' : 's'}'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final feed = ref.watch(notificationFeedByCategoryProvider(_category));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear all',
            onPressed: _clearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spaceLg,
              vertical: tokens.spaceSm,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final c in _filters) ...[
                    FilterChip(
                      label: Text(c == null ? 'All' : categoryLabel(c)),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                    SizedBox(width: tokens.spaceSm),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: AsyncFade<List<Notification>>(
              value: feed,
              loading: () => const ListSkeleton(),
              error: (e, _) => ErrorView(
                message: 'Failed to load activity: $e',
                onRetry: () => ref.invalidate(
                  notificationFeedByCategoryProvider(_category),
                ),
              ),
              data: (rows) => rows.isEmpty
                  ? const EmptyState(
                      icon: Icons.notifications_none_outlined,
                      title: 'All caught up',
                      message: 'Background activity will show up here.',
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(bottom: tokens.spaceLg),
                      itemCount: rows.length,
                      itemBuilder: (_, i) => _NotificationTile(rows[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile(this.notification);

  final Notification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final style = severityStyle(scheme, notification.severity);
    final unread = notification.readAt == null;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) {
        ref.read(notificationsRepositoryProvider).dismiss(notification.id);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Dismissed')));
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: style.bg,
          foregroundColor: style.fg,
          child: Icon(style.icon),
        ),
        title: Text(
          notification.title,
          style: unread ? const TextStyle(fontWeight: FontWeight.w600) : null,
        ),
        subtitle: notification.body == null
            ? Text(relativeTime(notification.createdAt))
            : Text(
                '${notification.body}\n${relativeTime(notification.createdAt)}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
        isThreeLine: notification.body != null,
        trailing: unread
            ? Icon(Icons.circle, size: 10, color: scheme.primary)
            : null,
        onTap: () {
          final route = notification.targetRoute;
          if (route == null) return;
          ref.read(notificationsRepositoryProvider).markRead(notification.id);
          context.push(route);
        },
      ),
    );
  }
}
