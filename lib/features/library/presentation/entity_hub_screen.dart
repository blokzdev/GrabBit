import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/share/external_share_service.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/async_fade.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/graph_entity_providers.dart';
import 'package:grabbit/features/library/presentation/grid_sort.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';

/// A hub listing every library item belonging to one entity — an uploader,
/// platform (site), playlist, or tag. Pure Drift faceting (P10c-c-1); the graph
/// "related entities" strip is layered on in c-2.
class EntityHubScreen extends ConsumerStatefulWidget {
  const EntityHubScreen({
    required this.type,
    required this.value,
    this.displayName,
    super.key,
  });

  /// `uploader` | `site` | `playlist` | `tag`.
  final String type;

  /// The matching key (uploader name / site / playlistId / tag name).
  final String value;

  /// Human label for the app bar (e.g. a playlist's title, where [value] is its
  /// id). Falls back to [value], then a type label.
  final String? displayName;

  @override
  ConsumerState<EntityHubScreen> createState() => _EntityHubScreenState();
}

class _EntityHubScreenState extends ConsumerState<EntityHubScreen> {
  LibrarySort _sort = LibrarySort.newest;

  String get _typeLabel => switch (widget.type) {
    'uploader' => 'Channel',
    'site' => 'Platform',
    'playlist' => 'Playlist',
    'tag' => 'Tag',
    _ => 'Hub',
  };

  String get _title =>
      widget.displayName ??
      (widget.value.isNotEmpty ? widget.value : _typeLabel);

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final key = (type: widget.type, value: widget.value);
    final items = ref.watch(hubItemsProvider(key));
    final rows = items.asData?.value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              _typeLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (rows.isNotEmpty) ...[
            GridSortButton(
              value: _sort,
              onChanged: (s) => setState(() => _sort = s),
            ),
            IconButton(
              tooltip: 'Share all',
              icon: const Icon(Icons.ios_share),
              onPressed: () => ref
                  .read(externalShareServiceProvider)
                  .shareFiles([for (final r in rows) r.filePath]),
            ),
          ],
        ],
      ),
      body: ContentBounds(
        maxWidth: 1280,
        child: Column(
          children: [
            _RelatedTagsStrip(type: widget.type, value: widget.value),
            Expanded(
              child: AsyncFade(
                value: items,
                loading: () => const MediaGridSkeleton(),
                error: (e, _) => ErrorView(
                  message: 'Failed to load: $e',
                  onRetry: () => ref.invalidate(hubItemsProvider(key)),
                ),
                data: (rows) => rows.isEmpty
                    ? Padding(
                        padding: EdgeInsets.all(tokens.spaceLg),
                        child: const EmptyState(
                          icon: Icons.inbox_outlined,
                          title: 'Nothing here',
                          message: 'No items belong to this yet.',
                        ),
                      )
                    : MediaGrid(items: sortMediaItems(rows, _sort)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tags that co-occur with this hub's entity, as chips that open the
/// corresponding tag hub. Renders nothing when the graph is unavailable or has
/// no related tags, so the hub is unchanged on devices without the graph.
class _RelatedTagsStrip extends ConsumerWidget {
  const _RelatedTagsStrip({required this.type, required this.value});
  final String type;
  final String value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final tags =
        ref
            .watch(relatedTagsProvider((type: type, value: value)))
            .asData
            ?.value ??
        const [];
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceMd,
        tokens.spaceLg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Related tags',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: tokens.spaceXs),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceXs,
            children: [
              for (final tag in tags)
                ActionChip(
                  label: Text(tag),
                  onPressed: () => context.push(
                    Uri(
                      path: '/hub/tag',
                      queryParameters: {'v': tag},
                    ).toString(),
                    extra: tag,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
