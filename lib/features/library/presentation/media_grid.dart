import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';

/// Reusable thumbnail grid of media items (library + collection views).
class MediaGrid extends StatelessWidget {
  const MediaGrid({required this.items, this.physics, super.key});
  final List<MediaItem> items;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: physics,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _MediaTile(item: items[i]),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/item/${item.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Thumb(item: item),
                  if (item.storageState == 'exported')
                    const Positioned(top: 6, right: 6, child: _ExportedBadge()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
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

class _ExportedBadge extends StatelessWidget {
  const _ExportedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.save_alt, size: 14, color: Colors.white),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item});
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
