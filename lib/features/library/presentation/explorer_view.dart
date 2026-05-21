import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/features/library/data/folder_repository.dart';
import 'package:grabbit/features/library/presentation/folder_picker.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Prompts for a folder name (create or rename). Returns null if cancelled.
Future<String?> promptFolderName(
  BuildContext context, {
  required String title,
  String? initial,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Folder name'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// Creates a folder under the Explorer's current folder (used by the shell FAB).
Future<void> createFolderFlow(BuildContext context, WidgetRef ref) async {
  final name = await promptFolderName(context, title: 'New folder');
  if (name == null || name.trim().isEmpty) return;
  final parentId = ref.read(explorerFolderProvider);
  await ref
      .read(folderRepositoryProvider)
      .createFolder(name, parentId: parentId);
  if (context.mounted) _notify(context, 'Folder created');
}

/// The Explorer body: folder-tree navigation + the current folder's media, with
/// multi-select move. Hosted by HomeScreen's segmented toggle.
class ExplorerView extends ConsumerStatefulWidget {
  const ExplorerView({super.key});

  @override
  ConsumerState<ExplorerView> createState() => _ExplorerViewState();
}

class _ExplorerViewState extends ConsumerState<ExplorerView> {
  final Set<String> _selected = {};

  void _open(int? folderId) {
    setState(_selected.clear);
    ref.read(explorerFolderProvider.notifier).open(folderId);
  }

  void _toggle(MediaItem item) => setState(() {
    _selected.contains(item.id)
        ? _selected.remove(item.id)
        : _selected.add(item.id);
  });

  Future<void> _moveSelected() async {
    final choice = await pickFolder(context, ref);
    if (choice == null) return;
    final ids = _selected.toList();
    await ref.read(folderRepositoryProvider).moveItems(ids, choice.id);
    setState(_selected.clear);
    if (mounted) _notify(context, 'Moved ${ids.length} item(s)');
  }

  Future<void> _renameFolder(Folder folder) async {
    final name = await promptFolderName(
      context,
      title: 'Rename folder',
      initial: folder.name,
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(folderRepositoryProvider).renameFolder(folder.id, name);
  }

  Future<void> _deleteFolder(Folder folder) async {
    final ok = await confirm(
      context,
      title: 'Delete folder?',
      message:
          'Delete "${folder.name}"? Its subfolders and media move back to the '
          'library root (nothing is deleted).',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(folderRepositoryProvider).deleteFolder(folder.id);
    if (mounted) _notify(context, 'Folder deleted');
  }

  @override
  Widget build(BuildContext context) {
    final currentId = ref.watch(explorerFolderProvider);
    final crumbs = ref.watch(breadcrumbProvider(currentId)).asData?.value ?? [];
    final folders =
        ref.watch(subfoldersProvider(currentId)).asData?.value ?? [];
    final items = ref.watch(folderItemsProvider(currentId)).asData?.value ?? [];
    final selecting = _selected.isNotEmpty;

    return Column(
      children: [
        _Breadcrumb(crumbs: crumbs, onTap: _open),
        Expanded(
          child: (folders.isEmpty && items.isEmpty)
              ? const _EmptyFolder()
              : CustomScrollView(
                  slivers: [
                    SliverList.list(
                      children: [
                        for (final f in folders)
                          ListTile(
                            leading: const Icon(Icons.folder),
                            title: Text(f.name),
                            onTap: () => _open(f.id),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) => v == 'rename'
                                  ? _renameFolder(f)
                                  : _deleteFolder(f),
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Rename'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(12),
                      sliver: SliverGrid.builder(
                        gridDelegate: mediaGridDelegate,
                        itemCount: items.length,
                        itemBuilder: (context, i) => MediaTile(
                          item: items[i],
                          selectionMode: selecting,
                          selected: _selected.contains(items[i].id),
                          onTap: selecting ? _toggle : null,
                          onLongPress: _toggle,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        if (selecting)
          _SelectionBar(
            count: _selected.length,
            onMove: _moveSelected,
            onClear: () => setState(_selected.clear),
          ),
      ],
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.crumbs, required this.onTap});
  final List<Folder> crumbs;
  final void Function(int?) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          TextButton.icon(
            onPressed: () => onTap(null),
            icon: const Icon(Icons.home_outlined, size: 18),
            label: const Text('Library'),
          ),
          for (final f in crumbs) ...[
            const Icon(Icons.chevron_right, size: 18),
            TextButton(onPressed: () => onTap(f.id), child: Text(f.name)),
          ],
        ],
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onMove,
    required this.onClear,
  });
  final int count;
  final VoidCallback onMove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text('$count selected')),
              TextButton.icon(
                onPressed: onMove,
                icon: const Icon(Icons.drive_file_move_outlined),
                label: const Text('Move'),
              ),
              IconButton(
                tooltip: 'Clear',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFolder extends StatelessWidget {
  const _EmptyFolder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 72,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('This folder is empty', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Create subfolders or move media here.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
