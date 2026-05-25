import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphview/GraphView.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/graph/graph_query_provider.dart';
import 'package:grabbit/core/graph/graph_query_service.dart';
import 'package:grabbit/core/graph/graph_store_provider.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/async_fade.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/features/ai/presentation/graph_view_providers.dart';
import 'package:grabbit/features/ai/presentation/neighborhood_graph.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';

/// Renders + explores a media item's graph neighborhood (P10c-e render, P10c-f
/// interaction): the item at the centre with its channel/playlist/platform/tags
/// and any duplicate/co-downloaded media. Pan/zoom, tap a media node to open it,
/// tap an entity node to expand its media, long-press for more, and filter edge
/// types from the legend. Deterministic edges — no embedder.
class GraphViewScreen extends ConsumerStatefulWidget {
  const GraphViewScreen({required this.itemId, super.key});

  final String itemId;

  @override
  ConsumerState<GraphViewScreen> createState() => _GraphViewScreenState();
}

class _GraphViewScreenState extends ConsumerState<GraphViewScreen> {
  /// Entity node key → its pulled media children (present == expanded).
  final Map<String, List<GraphNeighbor>> _expanded = {};

  /// Relations hidden via the legend filters.
  final Set<String> _hidden = {};

  /// Entity keys currently loading their expansion.
  final Set<String> _loading = {};

  Future<void> _toggleExpand(GraphNeighbor entity) async {
    final key = neighborKey(entity);
    if (_expanded.containsKey(key)) {
      setState(() => _expanded.remove(key));
      return;
    }
    setState(() => _loading.add(key));
    final media = await ref
        .read(graphQueryServiceProvider)
        .entityMedia(entity.relation, entity.id);
    if (!mounted) return;
    setState(() {
      _loading.remove(key);
      // Drop the centre item — it's already the root node.
      _expanded[key] = [
        for (final m in media)
          if (m.id != widget.itemId) m,
      ];
    });
  }

  void _open(GraphNeighbor n) {
    final target = navTargetFor(n);
    context.push(target.location, extra: target.extra);
  }

  Future<void> _onLongPress(GraphNeighbor n) async {
    final expanded = _expanded.containsKey(neighborKey(n));
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(relationIcon(n.relation)),
              title: Text(
                n.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(relationLabel(n.relation)),
            ),
            const Divider(height: 1),
            if (isMediaRelation(n.relation))
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open item'),
                onTap: () {
                  Navigator.of(sheet).pop();
                  _open(n);
                },
              )
            else ...[
              ListTile(
                leading: Icon(
                  expanded ? Icons.unfold_less : Icons.account_tree_outlined,
                ),
                title: Text(expanded ? 'Collapse' : 'Expand'),
                onTap: () {
                  Navigator.of(sheet).pop();
                  _toggleExpand(n);
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open hub'),
                onTap: () {
                  Navigator.of(sheet).pop();
                  _open(n);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onTap(GraphNeighbor n) {
    if (isEntityRelation(n.relation)) {
      _toggleExpand(n);
    } else {
      _open(n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(graphStoreProvider).isAvailable;
    final neighbors = ref.watch(graphNeighborhoodProvider(widget.itemId));
    final center = ref
        .watch(mediaItemByIdProvider(widget.itemId))
        .asData
        ?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Graph')),
      body: !available
          ? const EmptyState(
              icon: Icons.hub_outlined,
              title: 'Graph unavailable',
              message: "The on-device graph isn't available on this device.",
            )
          : AsyncFade(
              value: neighbors,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: 'Failed to load the graph: $e',
                onRetry: () =>
                    ref.invalidate(graphNeighborhoodProvider(widget.itemId)),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.hub_outlined,
                      title: 'No connections yet',
                      message: 'This item has no graph connections yet.',
                    )
                  : _canvas(center, list),
            ),
    );
  }

  Widget _canvas(MediaItem? center, List<GraphNeighbor> neighbors) {
    // Every node a builder might render, keyed by its node key.
    final byKey = {
      for (final n in neighbors) neighborKey(n): n,
      for (final children in _expanded.values)
        for (final c in children) neighborKey(c): c,
    };
    // Which relations are present, for the legend filters.
    final present = {for (final n in neighbors) n.relation};

    final graph = buildNeighborhoodGraph(
      centerId: center?.id ?? '',
      neighbors: neighbors,
      expanded: _expanded,
      hiddenRelations: _hidden,
      edgePaint: (relation) => Paint()
        ..color = relationColor(relation).withValues(alpha: 0.6)
        ..strokeWidth = 1.5,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(400),
            minScale: 0.2,
            maxScale: 3,
            child: GraphView(
              graph: graph,
              algorithm: FruchtermanReingoldAlgorithm(
                FruchtermanReingoldConfiguration(),
              ),
              animated: false,
              builder: (node) {
                final key = node.key!.value as String;
                if (key == kCenterKey) return _CenterNode(item: center);
                final n = byKey[key];
                if (n == null) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () => _onTap(n),
                  onLongPress: () => _onLongPress(n),
                  child: _NeighborNode(
                    neighbor: n,
                    expanded: _expanded.containsKey(key),
                    loading: _loading.contains(key),
                  ),
                );
              },
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _LegendFilters(
            present: present,
            hidden: _hidden,
            onToggle: (relation) => setState(
              () => _hidden.contains(relation)
                  ? _hidden.remove(relation)
                  : _hidden.add(relation),
            ),
          ),
        ),
      ],
    );
  }
}

class _CenterNode extends StatelessWidget {
  const _CenterNode({required this.item});

  final MediaItem? item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Container(
      width: 132,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(color: theme.colorScheme.primary, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: MediaThumb(item: item!),
            ),
          Padding(
            padding: EdgeInsets.all(tokens.spaceSm),
            child: Text(
              item?.title ?? 'This item',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeighborNode extends StatelessWidget {
  const _NeighborNode({
    required this.neighbor,
    this.expanded = false,
    this.loading = false,
  });

  final GraphNeighbor neighbor;
  final bool expanded;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final color = relationColor(neighbor.relation);
    final isEntity = isEntityRelation(neighbor.relation);
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceSm,
        vertical: tokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: expanded
            ? color.withValues(alpha: 0.16)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(relationIcon(neighbor.relation), size: 16, color: color),
          SizedBox(width: tokens.spaceXs),
          Flexible(
            child: Text(
              neighbor.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ),
          if (isEntity) ...[
            SizedBox(width: tokens.spaceXs),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 14,
              color: color,
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom legend whose chips also filter edge/node types on/off.
class _LegendFilters extends StatelessWidget {
  const _LegendFilters({
    required this.present,
    required this.hidden,
    required this.onToggle,
  });

  final Set<String> present;
  final Set<String> hidden;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final relations = [
      for (final r in kNeighborRelations)
        if (present.contains(r)) r,
    ];
    if (relations.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: EdgeInsets.all(tokens.spaceMd),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spaceMd,
          vertical: tokens.spaceSm,
        ),
        child: Wrap(
          spacing: tokens.spaceSm,
          runSpacing: tokens.spaceXs,
          alignment: WrapAlignment.center,
          children: [
            for (final relation in relations)
              FilterChip(
                label: Text(relationLabel(relation)),
                avatar: Icon(
                  relationIcon(relation),
                  size: 16,
                  color: relationColor(relation),
                ),
                selected: !hidden.contains(relation),
                onSelected: (_) => onToggle(relation),
              ),
          ],
        ),
      ),
    );
  }
}
