import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/share/external_share_service.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/features/library/data/folder_repository.dart';
import 'package:grabbit/features/library/data/library_repository.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/folder_picker.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// Shared per-item action menu + the action helpers behind it. The helpers take
/// a list so the P9h multi-select bulk bar reuses the exact same code; the
/// single-item menu just passes `[item]`. (P9g)
Future<void> showMediaActions(
  BuildContext context,
  WidgetRef ref,
  MediaItem item, {
  VoidCallback? onSelect,
}) {
  return showModalBottomSheet<void>(
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
              if (onSelect != null)
                action(Icons.check_circle_outline, 'Select', onSelect),
              action(
                Icons.open_in_new,
                'Open',
                () => context.push('/item/${item.id}'),
              ),
              action(
                item.isFavorite ? Icons.star : Icons.star_outline,
                item.isFavorite ? 'Unfavorite' : 'Favorite',
                () => favoriteItems(ref, [item]),
              ),
              action(
                Icons.save_alt,
                'Save to device',
                () => saveItems(context, ref, [item]),
              ),
              action(
                Icons.playlist_add,
                'Add to collection',
                () => addItemsToCollection(context, ref, [item]),
              ),
              action(
                Icons.drive_file_move_outlined,
                'Move to folder',
                () => moveItemsTo(context, ref, [item]),
              ),
              action(
                Icons.edit_outlined,
                'Edit info',
                () => context.push('/item/${item.id}/edit'),
              ),
              action(
                Icons.auto_fix_high_outlined,
                'Edit in Studio',
                () => context.push('/item/${item.id}/studio'),
              ),
              action(
                Icons.ios_share,
                'Share file',
                () => shareItems(ref, [item]),
              ),
              action(
                Icons.link,
                'Copy source URL',
                () => copyUrl(context, [item]),
              ),
              action(
                Icons.open_in_browser,
                'Open source link',
                () => ref
                    .read(externalShareServiceProvider)
                    .openUrl(item.sourceUrl),
              ),
              action(
                Icons.delete_outline,
                'Delete',
                () => deleteItems(context, ref, [item]),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Favorites the items, or unfavorites them when they're all already favorite.
Future<void> favoriteItems(WidgetRef ref, List<MediaItem> items) async {
  if (items.isEmpty) return;
  final repo = ref.read(metadataRepositoryProvider);
  final makeFavorite = items.any((i) => !i.isFavorite);
  for (final item in items) {
    await repo.toggleFavorite(item.id, makeFavorite);
  }
}

Future<void> saveItems(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final folder = ref
      .read(settingsControllerProvider)
      .asData
      ?.value
      .exportFolder;
  final repo = ref.read(libraryRepositoryProvider);
  var saved = 0;
  for (final item in items) {
    try {
      await repo.export(item, treeUri: folder);
      saved++;
    } catch (_) {
      // Best-effort: a single failure shouldn't abort the batch.
    }
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          saved == items.length
              ? 'Saved to device'
              : 'Saved $saved of ${items.length}',
        ),
      ),
    );
}

Future<void> deleteItems(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items,
) async {
  if (items.isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);
  final single = items.length == 1;
  final ok = await confirm(
    context,
    title: single ? 'Delete this item?' : 'Delete ${items.length} items?',
    message:
        'Permanently removes the downloaded file${single ? '' : 's'} from '
        'GrabBit. This cannot be undone.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!ok) return;
  final secure =
      ref.read(settingsControllerProvider).asData?.value.secureDelete ?? false;
  final repo = ref.read(libraryRepositoryProvider);
  for (final item in items) {
    await repo.deleteItem(item, secure: secure);
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(single ? 'Deleted' : 'Deleted ${items.length} items'),
      ),
    );
}

Future<void> moveItemsTo(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items,
) async {
  if (items.isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);
  final choice = await pickFolder(context, ref);
  if (choice == null) return;
  await ref.read(folderRepositoryProvider).moveItems([
    for (final item in items) item.id,
  ], choice.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Moved')));
}

Future<void> addItemsToCollection(
  BuildContext context,
  WidgetRef ref,
  List<MediaItem> items,
) async {
  if (items.isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);
  final collectionId = await _pickCollection(context, ref);
  if (collectionId == null) return;
  final repo = ref.read(metadataRepositoryProvider);
  for (final item in items) {
    await repo.addItemToCollection(item.id, collectionId);
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Added to collection')));
}

Future<void> shareItems(WidgetRef ref, List<MediaItem> items) {
  return ref.read(externalShareServiceProvider).shareFiles([
    for (final item in items) item.filePath,
  ]);
}

Future<void> copyUrl(BuildContext context, List<MediaItem> items) async {
  if (items.isEmpty) return;
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(
    ClipboardData(text: [for (final item in items) item.sourceUrl].join('\n')),
  );
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Copied source URL')));
}

/// Picks an existing collection or creates a new one; returns its id or null.
Future<int?> _pickCollection(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => Consumer(
      builder: (consumerContext, sheetRef, _) {
        final collections =
            sheetRef.watch(collectionsProvider).asData?.value ?? const [];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('New collection…'),
                onTap: () async {
                  final name = await _promptCollectionName(sheetContext);
                  if (name == null) return;
                  final id = await sheetRef
                      .read(metadataRepositoryProvider)
                      .createCollection(name);
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop(id);
                  }
                },
              ),
              for (final collection in collections)
                ListTile(
                  leading: const Icon(Icons.collections_bookmark_outlined),
                  title: Text(collection.name),
                  onTap: () => Navigator.of(sheetContext).pop(collection.id),
                ),
            ],
          ),
        );
      },
    ),
  );
}

Future<String?> _promptCollectionName(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New collection'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Name'),
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
          child: const Text('Create'),
        ),
      ],
    ),
  );
}
