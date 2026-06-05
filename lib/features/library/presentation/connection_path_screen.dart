import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/async_fade.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/features/library/presentation/connection_path_provider.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';

/// "How are these related?" (P13e-3a): renders the shortest connection between
/// two library items as a readable chain — a card per item with the relation
/// connector between consecutive items.
class ConnectionPathScreen extends ConsumerWidget {
  const ConnectionPathScreen({
    required this.sourceId,
    required this.targetId,
    super.key,
  });

  final String sourceId;
  final String targetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (sourceId, targetId);
    final view = ref.watch(connectionPathProvider(key));
    return Scaffold(
      appBar: AppBar(title: const Text('Connection')),
      body: ContentBounds(
        child: AsyncFade(
          value: view,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(
            message: 'Failed to find a connection: $e',
            onRetry: () => ref.invalidate(connectionPathProvider(key)),
          ),
          data: (v) => v == null
              ? const EmptyState(
                  icon: Icons.link_off,
                  title: 'No connection found',
                  message: "These items aren't linked in your library graph.",
                )
              : _Chain(view: v),
        ),
      ),
    );
  }
}

class _Chain extends StatelessWidget {
  const _Chain({required this.view});

  final ConnectionPathView view;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return ListView(
      padding: EdgeInsets.all(tokens.spaceMd),
      children: [
        for (var i = 0; i < view.items.length; i++) ...[
          _ItemCard(item: view.items[i]),
          if (i < view.connectors.length) _Connector(label: view.connectors[i]),
        ],
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          child: SizedBox(width: 72, height: 48, child: MediaThumb(item: item)),
        ),
        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(item.site),
        onTap: () => context.push('/item/${item.id}'),
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spaceXs),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Center(
              child: Container(
                width: 2,
                height: 28,
                color: scheme.outlineVariant,
              ),
            ),
          ),
          SizedBox(width: tokens.spaceMd),
          Icon(Icons.link, size: 16, color: scheme.onSurfaceVariant),
          SizedBox(width: tokens.spaceXs),
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
