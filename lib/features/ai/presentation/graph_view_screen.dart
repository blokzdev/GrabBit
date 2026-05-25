import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphview/GraphView.dart';
import 'package:grabbit/core/db/database.dart';
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

/// Renders a media item's immediate graph neighborhood as a force-directed graph
/// (P10c-e): the item at the centre, its channel/playlist/platform/tags and any
/// duplicate/co-downloaded media around it. Pan/zoom + a type legend. Tap-to-
/// navigate, expand/collapse and edge filters land in P10c-f.
class GraphViewScreen extends ConsumerWidget {
  const GraphViewScreen({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(graphStoreProvider).isAvailable;
    final neighbors = ref.watch(graphNeighborhoodProvider(itemId));
    final center = ref.watch(mediaItemByIdProvider(itemId)).asData?.value;

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
                    ref.invalidate(graphNeighborhoodProvider(itemId)),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.hub_outlined,
                      title: 'No connections yet',
                      message: 'This item has no graph connections yet.',
                    )
                  : _GraphCanvas(center: center, neighbors: list),
            ),
    );
  }
}

class _GraphCanvas extends StatelessWidget {
  const _GraphCanvas({required this.center, required this.neighbors});

  final MediaItem? center;
  final List<GraphNeighbor> neighbors;

  @override
  Widget build(BuildContext context) {
    final byKey = {for (final n in neighbors) neighborKey(n): n};
    final graph = buildNeighborhoodGraph(
      centerId: center?.id ?? '',
      neighbors: neighbors,
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
                return n == null
                    ? const SizedBox.shrink()
                    : _NeighborNode(neighbor: n);
              },
            ),
          ),
        ),
        const Align(alignment: Alignment.bottomCenter, child: _Legend()),
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
  const _NeighborNode({required this.neighbor});

  final GraphNeighbor neighbor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final color = relationColor(neighbor.relation);
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceSm,
        vertical: tokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
        ],
      ),
    );
  }
}

/// Maps node/edge colours to relation types.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Card(
      margin: EdgeInsets.all(tokens.spaceMd),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spaceMd,
          vertical: tokens.spaceSm,
        ),
        child: Wrap(
          spacing: tokens.spaceMd,
          runSpacing: tokens.spaceXs,
          alignment: WrapAlignment.center,
          children: [
            for (final relation in kNeighborRelations)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    relationIcon(relation),
                    size: 14,
                    color: relationColor(relation),
                  ),
                  SizedBox(width: tokens.spaceXs),
                  Text(
                    relationLabel(relation),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
