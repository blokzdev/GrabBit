import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';

/// Hero tag for an item's thumbnail (tile → detail flight). Shared so the
/// detail screen can match it.
String mediaHeroTag(String itemId) => 'media-thumb-$itemId';

/// Reusable thumbnail grid of media items (library + collection views).
class MediaGrid extends StatelessWidget {
  const MediaGrid({required this.items, this.physics, super.key});
  final List<MediaItem> items;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return GridView.builder(
      physics: physics,
      padding: EdgeInsets.all(tokens.spaceMd),
      gridDelegate: mediaGridDelegate,
      itemCount: items.length,
      itemBuilder: (context, i) => MediaTile(item: items[i]),
    );
  }
}

const mediaGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 220,
  childAspectRatio: 0.8,
  crossAxisSpacing: 12,
  mainAxisSpacing: 12,
);

/// A single media thumbnail tile. Tapping opens the detail screen by default;
/// pass [onTap]/[onLongPress] (e.g. for Explorer selection) to override, and
/// [selectionMode]/[selected] to show a selection check.
class MediaTile extends StatelessWidget {
  const MediaTile({
    required this.item,
    this.selectionMode = false,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final MediaItem item;
  final bool selectionMode;
  final bool selected;
  final void Function(MediaItem)? onTap;
  final void Function(MediaItem)? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final radius = BorderRadius.circular(tokens.radiusMd);
    return InkWell(
      onTap: onTap != null
          ? () => onTap!(item)
          : () => context.push('/item/${item.id}'),
      onLongPress: onLongPress == null ? null : () => onLongPress!(item),
      borderRadius: radius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Hero(
              tag: mediaHeroTag(item.id),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MediaThumb(item: item),
                    if (item.type == 'video') const _PlayBadge(),
                    if (item.storageState == 'exported')
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: _OverlayBadge(icon: Icons.save_alt),
                      ),
                    if (selectionMode)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: _OverlayBadge(
                          icon: selected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          tint: selected ? theme.colorScheme.primary : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: tokens.spaceXs),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// A centered video affordance over the thumbnail (so video reads distinctly
/// from audio/image tiles).
class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.scrim.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

/// A small circular scrim badge for overlays on arbitrary thumbnail imagery,
/// where fixed light-on-scrim stays legible regardless of theme/photo.
class _OverlayBadge extends StatelessWidget {
  const _OverlayBadge({required this.icon, this.tint});
  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: scheme.scrim.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: tint ?? Colors.white),
    );
  }
}

/// The item's thumbnail image with a typed fallback. Public so the detail
/// screen can reuse it as the Hero flight shuttle.
class MediaThumb extends StatelessWidget {
  const MediaThumb({required this.item, super.key});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        item.type == 'audio' ? Icons.music_note : Icons.movie_outlined,
        color: scheme.onSurfaceVariant,
        size: 40,
      ),
    );
    final thumbPath = item.thumbPath;
    if (thumbPath == null) return fallback;
    return Image.file(
      File(thumbPath),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
