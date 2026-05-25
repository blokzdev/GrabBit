import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/grid_sort.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';
import 'package:grabbit/features/library/presentation/suggested_albums_provider.dart';

/// A suggested similarity cluster (P10c-d-2): browse the grouped items and, with
/// one tap, **Save as collection** to turn the suggestion into real curation.
class SuggestedAlbumScreen extends ConsumerStatefulWidget {
  const SuggestedAlbumScreen({required this.album, super.key});

  /// Null when navigated to without a live suggestion (e.g. a cold deep link) —
  /// the empty state covers that.
  final SuggestedAlbum? album;

  @override
  ConsumerState<SuggestedAlbumScreen> createState() =>
      _SuggestedAlbumScreenState();
}

class _SuggestedAlbumScreenState extends ConsumerState<SuggestedAlbumScreen> {
  LibrarySort _sort = LibrarySort.newest;

  Future<void> _save() async {
    final album = widget.album;
    if (album == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final name = await _promptName(context, album.label);
    if (name == null || name.trim().isEmpty) return;
    final repo = ref.read(metadataRepositoryProvider);
    final id = await repo.createCollection(name.trim());
    for (final item in album.items) {
      await repo.addItemToCollection(item.id, id);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Saved to "${name.trim()}"')));
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.album?.items ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.album?.label ?? 'Suggested',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (items.isNotEmpty) ...[
            GridSortButton(
              value: _sort,
              onChanged: (s) => setState(() => _sort = s),
            ),
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Save'),
            ),
          ],
        ],
      ),
      body: ContentBounds(
        maxWidth: 1280,
        child: items.isEmpty
            ? const EmptyState(
                icon: Icons.auto_awesome_outlined,
                title: 'Nothing here',
                message: 'This suggestion is no longer available.',
              )
            : MediaGrid(items: sortMediaItems(items, _sort)),
      ),
    );
  }

  Future<String?> _promptName(BuildContext context, String initial) {
    final controller = TextEditingController(text: initial);
    final tokens = GrabBitTokens.of(context);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save as collection'),
        content: Padding(
          padding: EdgeInsets.only(top: tokens.spaceXs),
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Collection name'),
            onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
