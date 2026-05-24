import 'package:flutter/material.dart';
import 'package:grabbit/core/theme/tokens.dart';

/// Slides + fades a bottom selection bar in and out (P9l): the height grows
/// from the bottom while the bar fades, instead of popping into the layout.
class SelectionBarTransition extends StatelessWidget {
  const SelectionBarTransition({
    required this.visible,
    required this.child,
    super.key,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = GrabBitTokens.of(context).motionMedium;
    return AnimatedSize(
      duration: duration,
      alignment: Alignment.bottomCenter,
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: duration,
        child: visible
            ? child
            : const SizedBox(width: double.infinity, height: 0),
      ),
    );
  }
}

/// Bottom action bar shown while multi-selecting media (P9h). Mirrors the
/// Explorer selection bar: a count + bulk actions, reused across grids.
class MediaSelectionBar extends StatelessWidget {
  const MediaSelectionBar({
    required this.count,
    required this.onClear,
    required this.onSelectAll,
    required this.onDelete,
    required this.onSave,
    required this.onMove,
    required this.onAddToCollection,
    required this.onFavorite,
    required this.onShare,
    super.key,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;
  final VoidCallback onSave;
  final VoidCallback onMove;
  final VoidCallback onAddToCollection;
  final VoidCallback onFavorite;
  final VoidCallback onShare;

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
            horizontal: tokens.spaceSm,
            vertical: tokens.spaceSm,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Clear',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
              Text('$count selected'),
              const Spacer(),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
              IconButton(
                tooltip: 'Save to device',
                onPressed: onSave,
                icon: const Icon(Icons.save_alt),
              ),
              IconButton(
                tooltip: 'Move to folder',
                onPressed: onMove,
                icon: const Icon(Icons.drive_file_move_outlined),
              ),
              IconButton(
                tooltip: 'Add to collection',
                onPressed: onAddToCollection,
                icon: const Icon(Icons.playlist_add),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (value) => switch (value) {
                  'favorite' => onFavorite(),
                  'share' => onShare(),
                  _ => onSelectAll(),
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'favorite', child: Text('Favorite')),
                  PopupMenuItem(value: 'share', child: Text('Share')),
                  PopupMenuItem(value: 'all', child: Text('Select all')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
