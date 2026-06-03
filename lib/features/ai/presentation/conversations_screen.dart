import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/widgets/async_fade.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/ai/data/chat_repository.dart';
import 'package:grabbit/features/notifications/presentation/notification_style.dart';

/// The "Ask your library" conversation list (P13d-2b): past chats,
/// most-recent-first, that you can continue / rename / archive / delete. The
/// Dashboard entry lands here; "New chat" (and the empty-state CTA) open a fresh
/// chat at `/ask/chat`. Archived threads live behind `/ask/archived`.
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(activeChatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask your library'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'archived') context.push('/ask/archived');
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'archived', child: Text('Archived chats')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/ask/chat'),
        icon: const Icon(Icons.add),
        label: const Text('New chat'),
      ),
      body: ContentBounds(
        child: AsyncFade(
          value: chats,
          loading: () => const ListSkeleton(),
          error: (e, _) => ErrorView(
            message: 'Failed to load your chats: $e',
            onRetry: () => ref.invalidate(activeChatsProvider),
          ),
          data: (list) => list.isEmpty
              ? EmptyState(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Ask your library',
                  message:
                      'Ask a question and get an answer grounded in your '
                      'downloads, with links to the items it used.',
                  action: FilledButton.icon(
                    onPressed: () => context.push('/ask/chat'),
                    icon: const Icon(Icons.add),
                    label: const Text('Start a chat'),
                  ),
                )
              : ListView(children: [for (final c in list) _ChatTile(item: c)]),
        ),
      ),
    );
  }
}

/// The archived conversations (kept + restorable). Same list, but per-row
/// actions are Unarchive / Delete.
class ArchivedChatsScreen extends ConsumerWidget {
  const ArchivedChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(archivedChatsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Archived chats')),
      body: ContentBounds(
        child: AsyncFade(
          value: chats,
          loading: () => const ListSkeleton(),
          error: (e, _) => ErrorView(
            message: 'Failed to load archived chats: $e',
            onRetry: () => ref.invalidate(archivedChatsProvider),
          ),
          data: (list) => list.isEmpty
              ? const EmptyState(
                  icon: Icons.archive_outlined,
                  title: 'No archived chats',
                  message:
                      'Chats you archive are kept here and can be restored.',
                )
              : ListView(children: [for (final c in list) _ChatTile(item: c)]),
        ),
      ),
    );
  }
}

/// One conversation row: title, a preview of the latest message + when it was
/// last touched, and an overflow menu whose actions depend on whether the chat
/// is archived. Tapping continues the conversation.
class _ChatTile extends ConsumerWidget {
  const _ChatTile({required this.item});

  final ChatListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final preview = item.preview?.replaceAll(RegExp(r'\s+'), ' ').trim();
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        child: const Icon(Icons.forum_outlined),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        preview == null || preview.isEmpty
            ? relativeTime(item.updatedAt)
            : '$preview · ${relativeTime(item.updatedAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'More',
        onSelected: (value) => _onAction(context, ref, value),
        itemBuilder: (context) => item.archived
            ? const [
                PopupMenuItem(value: 'unarchive', child: Text('Unarchive')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ]
            : const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'archive', child: Text('Archive')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
      ),
      onTap: () => context.push('/ask/chat/${item.id}'),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    final repo = ref.read(chatRepositoryProvider);
    switch (value) {
      case 'rename':
        final name = await _promptName(context, item.title);
        if (name == null) return;
        await repo.renameChat(item.id, name);
        if (context.mounted) _notify(context, 'Renamed');
      case 'archive':
        await repo.setArchived(item.id, true);
        if (context.mounted) _notify(context, 'Chat archived');
      case 'unarchive':
        await repo.setArchived(item.id, false);
        if (context.mounted) _notify(context, 'Chat restored');
      case 'delete':
        final ok = await confirm(
          context,
          title: 'Delete chat?',
          message:
              'Delete "${item.title}"? This conversation can\'t be '
              'recovered.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!ok) return;
        await repo.deleteChat(item.id);
        if (context.mounted) _notify(context, 'Chat deleted');
    }
  }

  Future<String?> _promptName(BuildContext context, String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Title'),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.of(dialogContext).pop(v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.of(dialogContext).pop(v);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
