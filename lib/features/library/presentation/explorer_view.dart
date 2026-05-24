import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/library/data/folder_repository.dart';
import 'package:grabbit/features/library/presentation/folder_picker.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';
import 'package:grabbit/features/library/presentation/media_selection_bar.dart';

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
    final foldersAsync = ref.watch(subfoldersProvider(currentId));
    final itemsAsync = ref.watch(folderItemsProvider(currentId));
    final selecting = _selected.isNotEmpty;

    final Widget body;
    if (foldersAsync.hasError || itemsAsync.hasError) {
      final error = foldersAsync.error ?? itemsAsync.error;
      body = ErrorView(
        message: 'Failed to load folder: $error',
        onRetry: () {
          ref.invalidate(subfoldersProvider(currentId));
          ref.invalidate(folderItemsProvider(currentId));
        },
      );
    } else if (!foldersAsync.hasValue || !itemsAsync.hasValue) {
      body = const MediaGridSkeleton();
    } else {
      final folders = foldersAsync.value!;
      final items = itemsAsync.value!;
      body = (folders.isEmpty && items.isEmpty)
          ? EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'This folder is empty',
              message: 'Create subfolders or move media here.',
              action: FilledButton.icon(
                onPressed: () => createFolderFlow(context, ref),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('Create folder'),
              ),
            )
          : _grid(context, folders, items, selecting);
    }

    return ContentBounds(
      maxWidth: 1280,
      child: Column(
        children: [
          _Breadcrumb(crumbs: crumbs, onTap: _open),
          Expanded(
            child: AnimatedSwitcher(
              duration: GrabBitTokens.of(context).motionMedium,
              child: body,
            ),
          ),
          SelectionBarTransition(
            visible: selecting,
            child: _SelectionBar(
              count: _selected.length,
              onMove: _moveSelected,
              onClear: () => setState(_selected.clear),
            ),
          ),
        ],
      ),
    );
  }

  /// One unified grid: folder cards flow into media tiles. Folders aren't
  /// selectable (tap opens); only media participate in multi-select.
  Widget _grid(
    BuildContext context,
    List<Folder> folders,
    List<MediaItem> items,
    bool selecting,
  ) {
    final tokens = GrabBitTokens.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(tokens.spaceMd),
          sliver: SliverGrid.builder(
            gridDelegate: mediaGridDelegate,
            itemCount: folders.length + items.length,
            itemBuilder: (context, i) {
              if (i < folders.length) {
                final folder = folders[i];
                return _FolderCard(
                  folder: folder,
                  onTap: () => _open(folder.id),
                  onRename: () => _renameFolder(folder),
                  onDelete: () => _deleteFolder(folder),
                );
              }
              final item = items[i - folders.length];
              return MediaTile(
                item: item,
                selectionMode: selecting,
                selected: _selected.contains(item.id),
                onTap: selecting ? _toggle : null,
                onLongPress: _toggle,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A folder tile in the Explorer grid: glyph + name + item count, with a
/// rename/delete overflow menu. Sized to the shared media-tile footprint.
class _FolderCard extends ConsumerWidget {
  const _FolderCard({
    required this.folder,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final Folder folder;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    final count =
        ref.watch(folderItemCountsProvider).asData?.value[folder.id] ?? 0;

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_rounded, color: scheme.primary),
                  const Spacer(),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    tooltip: 'Folder actions',
                    onSelected: (v) => v == 'rename' ? onRename() : onDelete(),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text(
                folder.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              SizedBox(height: tokens.spaceXs),
              Text(
                '$count item${count == 1 ? '' : 's'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.crumbs, required this.onTap});
  final List<Folder> crumbs;
  final void Function(int?) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = GrabBitTokens.of(context);
    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: tokens.spaceSm),
          children: [
            TextButton.icon(
              onPressed: () => onTap(null),
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Library'),
            ),
            for (final f in crumbs) ...[
              Icon(
                Icons.chevron_right,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              TextButton(onPressed: () => onTap(f.id), child: Text(f.name)),
            ],
          ],
        ),
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
    final tokens = GrabBitTokens.of(context);
    return Material(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spaceMd,
            vertical: tokens.spaceSm,
          ),
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
