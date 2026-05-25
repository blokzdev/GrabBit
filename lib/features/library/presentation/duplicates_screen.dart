import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/byte_format.dart';
import 'package:grabbit/core/widgets/async_fade.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/library/data/dedupe_service.dart';
import 'package:grabbit/features/library/data/library_repository.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/dedupe_actions.dart';
import 'package:grabbit/features/library/presentation/media_actions.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// Finds likely-duplicate downloads (same content signature) and lets the user
/// keep one and delete the rest (P9b-3).
class DuplicatesScreen extends ConsumerStatefulWidget {
  const DuplicatesScreen({super.key});

  @override
  ConsumerState<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends ConsumerState<DuplicatesScreen> {
  bool _scanning = false;
  bool _scanned = false;

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      await ref.read(dedupeServiceProvider).scan();
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
          _scanned = true;
        });
      }
    }
  }

  Future<void> _cleanUp() async {
    final groups = ref.read(duplicatesProvider).value ?? const [];
    final n = duplicatesToRemove(groups).length;
    if (n == 0) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirm(
      context,
      title: 'Remove duplicate copies?',
      message:
          'Keeps the oldest in each group and permanently deletes the other '
          '$n cop${n == 1 ? 'y' : 'ies'}. This cannot be undone.',
      confirmLabel: 'Remove $n',
      destructive: true,
    );
    if (!ok) return;
    final removed = await resolveDuplicates(ref);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed $removed cop${removed == 1 ? 'y' : 'ies'}'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(duplicatesProvider);
    final tokens = GrabBitTokens.of(context);
    final hasDupes = groups.asData?.value.isNotEmpty ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicates'),
        actions: [
          if (hasDupes)
            TextButton.icon(
              onPressed: _scanning ? null : _cleanUp,
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Clean up'),
            ),
          TextButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(_scanning ? 'Scanning…' : 'Scan'),
          ),
        ],
      ),
      body: ContentBounds(
        child: AsyncFade(
          value: groups,
          loading: () => const ListSkeleton(),
          error: (e, _) => ErrorView(
            message: 'Failed to load duplicates: $e',
            onRetry: () => ref.invalidate(duplicatesProvider),
          ),
          data: (list) => list.isEmpty
              ? EmptyState(
                  icon: _scanned
                      ? Icons.check_circle_outline
                      : Icons.content_copy_outlined,
                  title: _scanned
                      ? 'No duplicates found'
                      : 'Scan for duplicates',
                  message: _scanned
                      ? 'Your library has no duplicate downloads.'
                      : 'Tap Scan to find downloads with identical content.',
                  action: _scanned
                      ? null
                      : FilledButton.icon(
                          onPressed: _scanning ? null : _scan,
                          icon: const Icon(Icons.search),
                          label: const Text('Scan'),
                        ),
                )
              : ListView(
                  padding: EdgeInsets.all(tokens.spaceMd),
                  children: [
                    for (final group in list) _DuplicateGroup(items: group),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DuplicateGroup extends ConsumerWidget {
  const _DuplicateGroup({required this.items});
  final List<MediaItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Card(
      margin: EdgeInsets.only(bottom: tokens.spaceMd),
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spaceSm),
              child: Text(
                '${items.length} copies',
                style: theme.textTheme.titleSmall,
              ),
            ),
            for (final (i, item) in items.indexed)
              _DuplicateRow(item: item, isKept: i == 0),
          ],
        ),
      ),
    );
  }
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class _DuplicateRow extends ConsumerWidget {
  const _DuplicateRow({required this.item, this.isKept = false});
  final MediaItem item;

  /// The oldest copy in its group — the one bulk cleanup keeps. Badged so the
  /// user can tell at a glance which copy survives a "Clean up".
  final bool isKept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return ListTile(
      leading: SizedBox(
        width: 56,
        height: 40,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          child: MediaThumb(item: item),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isKept)
            Container(
              margin: EdgeInsets.only(left: tokens.spaceSm),
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spaceSm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(tokens.radiusPill),
              ),
              child: Text(
                'Keep',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        '${_ymd(item.createdAt.toLocal())} · ${formatBytes(item.sizeBytes)}',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete this copy',
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final ok = await confirm(
            context,
            title: 'Delete this copy?',
            message:
                'Permanently removes "${item.title}". This cannot be undone.',
            confirmLabel: 'Delete',
            destructive: true,
          );
          if (!ok) return;
          final secure =
              ref.read(settingsControllerProvider).asData?.value.secureDelete ??
              false;
          await ref
              .read(libraryRepositoryProvider)
              .deleteItem(item, secure: secure);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Deleted')));
        },
      ),
      onTap: () => context.push('/item/${item.id}'),
      onLongPress: () => showMediaActions(context, ref, item),
    );
  }
}
