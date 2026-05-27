import 'package:flutter/material.dart' hide Notification;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/share/external_share_service.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/notifications/data/notification_enums.dart';
import 'package:grabbit/features/notifications/data/notifications_repository.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';
import 'package:grabbit/features/queue/presentation/queue_controller.dart';

/// Per-entry context actions for an Activity Inbox tile (P11e): retry a failed
/// download, open/copy the source URL, share the downloaded file, dismiss.
///
/// Actions are gated on the entry's linked records, both of which may be absent
/// or already deleted — so they're resolved first and each row only renders when
/// its target still exists.
Future<void> showNotificationActions(
  BuildContext context,
  WidgetRef ref,
  Notification n,
) async {
  final item = n.itemId == null
      ? null
      : await ref.read(mediaItemByIdProvider(n.itemId!).future);
  final task = n.taskId == null
      ? null
      : await ref.read(queueRepositoryProvider).byId(n.taskId!);
  if (!context.mounted) return;

  final sourceUrl = item?.sourceUrl ?? task?.url;
  final canRetry =
      n.category == NotificationCategory.download &&
      n.severity == NotificationSeverity.error &&
      task != null;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      ListTile action(IconData icon, String label, VoidCallback run) =>
          ListTile(
            leading: Icon(icon),
            title: Text(label),
            onTap: () {
              Navigator.of(sheetContext).pop();
              run();
            },
          );
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canRetry)
                action(
                  Icons.refresh,
                  'Retry download',
                  () => _retry(context, ref, n),
                ),
              if (item != null)
                action(
                  Icons.ios_share,
                  'Share file',
                  () => ref.read(externalShareServiceProvider).shareFiles([
                    item.filePath,
                  ]),
                ),
              if (sourceUrl != null && sourceUrl.isNotEmpty) ...[
                action(
                  Icons.open_in_browser,
                  'Open source URL',
                  () =>
                      ref.read(externalShareServiceProvider).openUrl(sourceUrl),
                ),
                action(
                  Icons.link,
                  'Copy source URL',
                  () => _copyUrl(context, sourceUrl),
                ),
              ],
              action(
                Icons.delete_outline,
                'Dismiss',
                () => ref.read(notificationsRepositoryProvider).dismiss(n.id),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _retry(BuildContext context, WidgetRef ref, Notification n) async {
  await ref.read(queueControllerProvider.notifier).retry(n.taskId!);
  await ref.read(notificationsRepositoryProvider).dismiss(n.id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Retrying download…')));
}

Future<void> _copyUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: url));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Copied source URL')));
}
