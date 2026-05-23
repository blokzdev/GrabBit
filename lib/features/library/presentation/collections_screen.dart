import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Collections')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New collection'),
      ),
      body: ContentBounds(
        child: collections.when(
          loading: () => const ListSkeleton(),
          error: (e, _) => ErrorView(
            message: 'Failed to load collections: $e',
            onRetry: () => ref.invalidate(collectionsProvider),
          ),
          data: (list) => list.isEmpty
              ? EmptyState(
                  icon: Icons.collections_bookmark_outlined,
                  title: 'No collections yet',
                  message: 'Group items into collections to find them fast.',
                  action: FilledButton.icon(
                    onPressed: () => _create(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('New collection'),
                  ),
                )
              : ListView(
                  children: [
                    for (final c in list) _CollectionTile(collection: c),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(metadataRepositoryProvider).createCollection(name);
      if (context.mounted) _notify(context, 'Collection created');
    }
  }
}

class _CollectionTile extends ConsumerWidget {
  const _CollectionTile({required this.collection});
  final Collection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count =
        ref.watch(collectionItemCountsProvider).asData?.value[collection.id] ??
        0;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: const Icon(Icons.collections_bookmark),
      ),
      title: Text(collection.name),
      subtitle: Text('$count item${count == 1 ? '' : 's'}'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete collection',
        onPressed: () async {
          final ok = await confirm(
            context,
            title: 'Delete collection?',
            message:
                'Delete "${collection.name}"? The media stays in your library.',
            confirmLabel: 'Delete',
            destructive: true,
          );
          if (!ok) return;
          await ref
              .read(metadataRepositoryProvider)
              .deleteCollection(collection.id);
          if (context.mounted) _notify(context, 'Collection deleted');
        },
      ),
      onTap: () =>
          context.push('/collection/${collection.id}', extra: collection.name),
    );
  }
}

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({
    required this.collectionId,
    this.name,
    super.key,
  });

  final int collectionId;
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(collectionItemsProvider(collectionId));
    return Scaffold(
      appBar: AppBar(title: Text(name ?? 'Collection')),
      body: ContentBounds(
        maxWidth: 1280,
        child: items.when(
          loading: () => const MediaGridSkeleton(),
          error: (e, _) => ErrorView(
            message: 'Failed to load collection: $e',
            onRetry: () =>
                ref.invalidate(collectionItemsProvider(collectionId)),
          ),
          data: (rows) => rows.isEmpty
              ? const EmptyState(
                  icon: Icons.video_library_outlined,
                  title: 'This collection is empty',
                  message:
                      'Add items to this collection from their detail '
                      'screen.',
                )
              : MediaGrid(items: rows),
        ),
      ),
    );
  }
}
