import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collections = ref.watch(collectionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Collections')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _create(context, ref),
        child: const Icon(Icons.add),
      ),
      body: collections.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No collections yet'))
            : ListView(
                children: [
                  for (final c in list)
                    ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(c.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete collection',
                        onPressed: () async {
                          final ok = await confirm(
                            context,
                            title: 'Delete collection?',
                            message:
                                'Delete "${c.name}"? The media stays in your '
                                'library.',
                            confirmLabel: 'Delete',
                            destructive: true,
                          );
                          if (!ok) return;
                          await ref
                              .read(metadataRepositoryProvider)
                              .deleteCollection(c.id);
                          if (context.mounted) {
                            _notify(context, 'Collection deleted');
                          }
                        },
                      ),
                      onTap: () =>
                          context.push('/collection/${c.id}', extra: c.name),
                    ),
                ],
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
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (rows) => rows.isEmpty
            ? const Center(child: Text('This collection is empty'))
            : MediaGrid(items: rows),
      ),
    );
  }
}
