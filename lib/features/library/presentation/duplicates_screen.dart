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

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(duplicatesProvider);
    final tokens = GrabBitTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicates'),
        actions: [
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
            for (final item in items) _DuplicateRow(item: item),
          ],
        ),
      ),
    );
  }
}

class _DuplicateRow extends ConsumerWidget {
  const _DuplicateRow({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(formatBytes(item.sizeBytes)),
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
