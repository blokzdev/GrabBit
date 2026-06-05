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
import 'package:grabbit/features/library/presentation/connection_path_provider.dart';
import 'package:grabbit/features/library/presentation/item_picker.dart';
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

  /// Persists pan/zoom across rebuilds (expand, filter, the loading toggle).
  final TransformationController _transform = TransformationController();

  /// Last known canvas size, for centre-anchored zoom buttons.
  Size _viewport = Size.zero;

  /// Target item id when in path mode (P13e-3b); `null` = neighborhood mode.
  String? _pathTarget;

  // Memoized neighborhood graph — rebuilt only when its *structure* changes, so
  // unrelated `setState`s (e.g. the loading spinner) don't re-run the layout.
  Graph? _cachedGraph;
  String? _graphSig;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _findPath() async {
    final target = await pickLibraryItem(
      context,
      excludeId: widget.itemId,
      title: 'Find path to…',
    );
    if (target == null || !mounted) return;
    setState(() {
      _pathTarget = target;
      _transform.value = Matrix4.identity();
    });
  }

  void _exitPathMode() => setState(() {
    _pathTarget = null;
    _transform.value = Matrix4.identity();
  });

  void _zoom(double factor) {
    final c = _viewport.center(Offset.zero);
    _transform.value = _transform.value.clone()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(factor, factor, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }

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
    final center = ref
        .watch(mediaItemByIdProvider(widget.itemId))
        .asData
        ?.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(_pathTarget == null ? 'Graph' : 'Path'),
        actions: [
          if (available && _pathTarget == null)
            IconButton(
              icon: const Icon(Icons.alt_route),
              tooltip: 'Find path…',
              onPressed: _findPath,
            ),
        ],
      ),
      body: !available
          ? const EmptyState(
              icon: Icons.hub_outlined,
              title: 'Graph unavailable',
              message: "The on-device graph isn't available on this device.",
            )
          : _pathTarget != null
          ? _pathBody()
          : _neighborhoodBody(center),
    );
  }

  Widget _neighborhoodBody(MediaItem? center) {
    final neighbors = ref.watch(graphNeighborhoodProvider(widget.itemId));
    return AsyncFade(
      value: neighbors,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: 'Failed to load the graph: $e',
        onRetry: () => ref.invalidate(graphNeighborhoodProvider(widget.itemId)),
      ),
      data: (list) => list.isEmpty
          ? const EmptyState(
              icon: Icons.hub_outlined,
              title: 'No connections yet',
              message: 'This item has no graph connections yet.',
            )
          : _canvas(center, list),
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

    // Rebuild the graph only when its *structure* changes (not on every
    // setState — e.g. the loading spinner) so the force-directed layout doesn't
    // re-run and the nodes don't jump.
    final signature = _neighborhoodSignature(center, neighbors);
    if (_graphSig != signature) {
      _graphSig = signature;
      _cachedGraph = buildNeighborhoodGraph(
        centerId: center?.id ?? '',
        neighbors: neighbors,
        expanded: _expanded,
        hiddenRelations: _hidden,
        edgePaint: (relation) => Paint()
          ..color = relationColor(relation).withValues(alpha: 0.6)
          ..strokeWidth = 1.5,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(400),
                minScale: 0.2,
                maxScale: 3,
                child: GraphView(
                  graph: _cachedGraph!,
                  algorithm: FruchtermanReingoldAlgorithm(
                    FruchtermanReingoldConfiguration(),
                  ),
                  animated: false,
                  builder: (node) {
                    final key = node.key!.value as String;
                    if (key == kCenterKey) return _CenterNode(item: center);
                    final n = byKey[key];
                    if (n == null) return const SizedBox.shrink();
                    return Semantics(
                      label: '${relationLabel(n.relation)}: ${n.label}',
                      button: true,
                      child: GestureDetector(
                        onTap: () => _onTap(n),
                        onLongPress: () => _onLongPress(n),
                        child: _NeighborNode(
                          neighbor: n,
                          expanded: _expanded.containsKey(key),
                          loading: _loading.contains(key),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            _ZoomControls(
              onIn: () => _zoom(1.25),
              onOut: () => _zoom(0.8),
              onFit: _fit,
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
      },
    );
  }

  void _fit() => _transform.value = Matrix4.identity();

  String _neighborhoodSignature(
    MediaItem? center,
    List<GraphNeighbor> neighbors,
  ) {
    final b = StringBuffer(center?.id ?? '');
    for (final n in neighbors) {
      b
        ..write(';')
        ..write(neighborKey(n));
    }
    b.write('|h:');
    b.writeAll(_hidden.toList()..sort(), ',');
    b.write('|x:');
    for (final key in _expanded.keys.toList()..sort()) {
      b
        ..write(key)
        ..write('>')
        ..writeAll(_expanded[key]!.map(neighborKey), ',')
        ..write(';');
    }
    return b.toString();
  }

  Widget _pathBody() {
    final view = ref.watch(
      connectionPathProvider((widget.itemId, _pathTarget!)),
    );
    return AsyncFade(
      value: view,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: 'Failed to find a connection: $e',
        onRetry: () => ref.invalidate(
          connectionPathProvider((widget.itemId, _pathTarget!)),
        ),
      ),
      data: (v) => v == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyState(
                    icon: Icons.link_off,
                    title: 'No connection found',
                    message: "These items aren't linked in your library graph.",
                  ),
                  TextButton(
                    onPressed: _exitPathMode,
                    child: const Text('Back to neighborhood'),
                  ),
                ],
              ),
            )
          : _pathCanvas(v),
    );
  }

  Widget _pathCanvas(ConnectionPathView view) {
    final tokens = GrabBitTokens.of(context);
    // A path is a linear chain, so it's laid out deterministically (item node →
    // connector bridge → item node …) rather than via graphview's force-directed
    // engine — tidy, jitter-free, and not subject to graphview's headless-layout
    // fragility. Still in the pannable/zoomable graph canvas.
    final chain = <Widget>[];
    for (var i = 0; i < view.items.length; i++) {
      final item = view.items[i];
      chain.add(
        GestureDetector(
          onTap: () => context.push('/item/${item.id}'),
          onLongPress: () => context.push('/item/${item.id}/graph'),
          child: _PathItemNode(item: item),
        ),
      );
      if (i < view.connectors.length) {
        chain.add(_PathEdge(label: view.connectors[i]));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(400),
                minScale: 0.2,
                maxScale: 3,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spaceLg,
                    72, // clear the banner
                    tokens.spaceLg,
                    tokens.spaceLg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: chain,
                  ),
                ),
              ),
            ),
            _ZoomControls(
              onIn: () => _zoom(1.25),
              onOut: () => _zoom(0.8),
              onFit: _fit,
            ),
            Align(
              alignment: Alignment.topCenter,
              child: _PathBanner(view: view, onClose: _exitPathMode),
            ),
          ],
        );
      },
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

/// Zoom in / out / fit controls, anchored to the right of the canvas.
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onIn,
    required this.onOut,
    required this.onFit,
  });

  final VoidCallback onIn;
  final VoidCallback onOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: 'graphZoomIn',
              tooltip: 'Zoom in',
              onPressed: onIn,
              child: const Icon(Icons.add),
            ),
            SizedBox(height: tokens.spaceSm),
            FloatingActionButton.small(
              heroTag: 'graphZoomOut',
              tooltip: 'Zoom out',
              onPressed: onOut,
              child: const Icon(Icons.remove),
            ),
            SizedBox(height: tokens.spaceSm),
            FloatingActionButton.small(
              heroTag: 'graphFit',
              tooltip: 'Reset view',
              onPressed: onFit,
              child: const Icon(Icons.fit_screen_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

/// A media node on a highlighted path (P13e-3b).
class _PathItemNode extends StatelessWidget {
  const _PathItemNode({required this.item});

  final MediaItem? item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Semantics(
      label: 'Item: ${item?.title ?? ''}',
      button: true,
      child: Container(
        width: 124,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          border: Border.all(color: kPathHighlight, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fixed-size (not AspectRatio) so graphview's unbounded layout pass
            // always has a concrete size to measure.
            if (item != null)
              SizedBox(height: 70, child: MediaThumb(item: item!)),
            Padding(
              padding: EdgeInsets.all(tokens.spaceSm),
              child: Text(
                item?.title ?? 'Item',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A connector "bridge" node between two path items (P13e-3b).
class _BridgeNode extends StatelessWidget {
  const _BridgeNode({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceSm,
        vertical: tokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: kPathHighlight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(color: kPathHighlight, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link, size: 14, color: kPathHighlight),
          SizedBox(width: tokens.spaceXs),
          Flexible(
            child: Text(
              label,
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

/// A connector edge in the linear path render: a highlight line with the
/// connector bridge chip on it (P13e-3b).
class _PathEdge extends StatelessWidget {
  const _PathEdge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _EdgeLine(),
        _BridgeNode(label: label),
        const _EdgeLine(),
      ],
    );
  }
}

class _EdgeLine extends StatelessWidget {
  const _EdgeLine();

  @override
  Widget build(BuildContext context) =>
      Container(width: 2.5, height: 14, color: kPathHighlight);
}

/// Top banner naming the path's endpoints, with a close-to-neighborhood action.
class _PathBanner extends StatelessWidget {
  const _PathBanner({required this.view, required this.onClose});

  final ConnectionPathView view;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final theme = Theme.of(context);
    final first = view.items.first.title;
    final last = view.items.last.title;
    return Card(
      margin: EdgeInsets.all(tokens.spaceMd),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spaceMd,
          tokens.spaceSm,
          tokens.spaceSm,
          tokens.spaceSm,
        ),
        child: Row(
          children: [
            const Icon(Icons.alt_route, size: 18, color: kPathHighlight),
            SizedBox(width: tokens.spaceSm),
            Expanded(
              child: Text(
                '$first → $last',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Back to neighborhood',
              onPressed: onClose,
            ),
          ],
        ),
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
