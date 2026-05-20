import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';

class MetadataEditScreen extends ConsumerStatefulWidget {
  const MetadataEditScreen({required this.itemId, super.key});
  final String itemId;

  @override
  ConsumerState<MetadataEditScreen> createState() => _MetadataEditScreenState();
}

class _MetadataEditScreenState extends ConsumerState<MetadataEditScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagController = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(mediaItemByIdProvider(widget.itemId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      body: item.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load item: $e')),
        data: (row) {
          if (row == null) return const Center(child: Text('Item not found'));
          if (!_loaded) {
            _titleController.text = row.title;
            _notesController.text = row.notes ?? '';
            _loaded = true;
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              _TagsEditor(itemId: widget.itemId, controller: _tagController),
              const SizedBox(height: 24),
              _CollectionsEditor(itemId: widget.itemId),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final repo = ref.read(metadataRepositoryProvider);
    await repo.updateTitle(widget.itemId, _titleController.text);
    await repo.updateNotes(
      widget.itemId,
      _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    ref.invalidate(mediaItemByIdProvider(widget.itemId));
    if (mounted) Navigator.of(context).pop();
  }
}

class _TagsEditor extends ConsumerWidget {
  const _TagsEditor({required this.itemId, required this.controller});
  final String itemId;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsForItemProvider(itemId));
    final repo = ref.read(metadataRepositoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        tags.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (list) => Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in list)
                Chip(
                  label: Text(tag.name),
                  onDeleted: () => repo.removeTagFromItem(itemId, tag.id),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Add a tag',
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _add(repo),
            ),
          ),
          onSubmitted: (_) => _add(repo),
        ),
      ],
    );
  }

  void _add(MetadataRepository repo) {
    repo.addTagToItem(itemId, controller.text);
    controller.clear();
  }
}

class _CollectionsEditor extends ConsumerWidget {
  const _CollectionsEditor({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(collectionsProvider);
    final mine = ref.watch(collectionsForItemProvider(itemId));
    final repo = ref.read(metadataRepositoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Collections', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('New'),
              onPressed: () => _createDialog(context, repo),
            ),
          ],
        ),
        all.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (collections) {
            final memberIds = (mine.asData?.value ?? [])
                .map((c) => c.id)
                .toSet();
            if (collections.isEmpty) {
              return const Text('No collections yet.');
            }
            return Column(
              children: [
                for (final c in collections)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.name),
                    value: memberIds.contains(c.id),
                    onChanged: (checked) => (checked ?? false)
                        ? repo.addItemToCollection(itemId, c.id)
                        : repo.removeItemFromCollection(itemId, c.id),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _createDialog(
    BuildContext context,
    MetadataRepository repo,
  ) async {
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
      await repo.createCollection(name);
    }
  }
}
