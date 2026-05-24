import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';

enum _CollectionsTab { collections, albums }

/// Two ways to group the library: manual **Collections** and query-defined
/// **Albums** (smart/auto — by platform, channel, or recently played, P9b-2).
class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  _CollectionsTab _tab = _CollectionsTab.collections;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final onCollections = _tab == _CollectionsTab.collections;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spaceMd,
              0,
              tokens.spaceMd,
              tokens.spaceSm,
            ),
            child: SegmentedButton<_CollectionsTab>(
              segments: const [
                ButtonSegment(
                  value: _CollectionsTab.collections,
                  icon: Icon(Icons.collections_bookmark_outlined),
                  label: Text('Collections'),
                ),
                ButtonSegment(
                  value: _CollectionsTab.albums,
                  icon: Icon(Icons.auto_awesome_mosaic_outlined),
                  label: Text('Albums'),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
        ),
      ),
      floatingActionButton: onCollections
          ? FloatingActionButton.extended(
              onPressed: () => _create(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New collection'),
            )
          : null,
      body: ContentBounds(
        child: onCollections ? _buildCollections() : const _AlbumsView(),
      ),
    );
  }

  Widget _buildCollections() {
    final collections = ref.watch(collectionsProvider);
    return collections.when(
      loading: () => const ListSkeleton(),
      error: (e, _) => ErrorView(
        message: 'Failed to load collections: $e',
        onRetry: () => ref.invalidate(collectionsProvider),
      ),
      data: (list) => list.isEmpty
          ? EmptyState(
              icon: Icons.collections_bookmark_outlined,
              title: 'No collections yet',
              message: 'Group items into collections to find them fast.',
              action: FilledButton.icon(
                onPressed: () => _create(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('New collection'),
              ),
            )
          : ListView(
              children: [for (final c in list) _CollectionTile(collection: c)],
            ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(metadataRepositoryProvider).createCollection(name);
      if (context.mounted) _notify(context, 'Collection created');
    }
  }
}

class _CollectionTile extends ConsumerWidget {
  const _CollectionTile({required this.collection});
  final Collection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count =
        ref.watch(collectionItemCountsProvider).asData?.value[collection.id] ??
        0;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: const Icon(Icons.collections_bookmark),
      ),
      title: Text(collection.name),
      subtitle: Text('$count item${count == 1 ? '' : 's'}'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete collection',
        onPressed: () async {
          final ok = await confirm(
            context,
            title: 'Delete collection?',
            message:
                'Delete "${collection.name}"? The media stays in your library.',
            confirmLabel: 'Delete',
            destructive: true,
          );
          if (!ok) return;
          await ref
              .read(metadataRepositoryProvider)
              .deleteCollection(collection.id);
          if (context.mounted) _notify(context, 'Collection deleted');
        },
      ),
      onTap: () =>
          context.push('/collection/${collection.id}', extra: collection.name),
    );
  }
}

/// Smart/auto albums: query-defined groupings (platform, channel, recently
/// played) that fill in automatically — no manual curation.
class _AlbumsView extends ConsumerWidget {
  const _AlbumsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(distinctSitesProvider);
    final siteCounts = ref.watch(siteCountsProvider).asData?.value ?? const {};
    final uploaders =
        ref.watch(distinctUploadersProvider).asData?.value ?? const [];
    final uploaderCounts =
        ref.watch(uploaderCountsProvider).asData?.value ?? const {};
    final recent = ref.watch(recentlyPlayedProvider).asData?.value ?? const [];

    return sites.when(
      loading: () => const ListSkeleton(),
      error: (e, _) => ErrorView(
        message: 'Failed to load albums: $e',
        onRetry: () => ref.invalidate(distinctSitesProvider),
      ),
      data: (siteList) {
        if (siteList.isEmpty && uploaders.isEmpty && recent.isEmpty) {
          return const EmptyState(
            icon: Icons.auto_awesome_mosaic_outlined,
            title: 'No albums yet',
            message: 'Albums build automatically as you download media.',
          );
        }
        return ListView(
          children: [
            if (recent.isNotEmpty) ...[
              const SectionHeader('Quick'),
              _AlbumTile(
                icon: Icons.history,
                title: 'Recently played',
                count: recent.length,
                onTap: () => context.push('/album/recentPlayed'),
              ),
            ],
            if (siteList.isNotEmpty) ...[
              const SectionHeader('Platforms', icon: Icons.public),
              for (final s in siteList)
                _AlbumTile(
                  icon: Icons.public,
                  title: s,
                  count: siteCounts[s] ?? 0,
                  onTap: () =>
                      context.push('/album/site?v=${Uri.encodeComponent(s)}'),
                ),
            ],
            if (uploaders.isNotEmpty) ...[
              const SectionHeader('Channels', icon: Icons.person_outline),
              for (final u in uploaders)
                _AlbumTile(
                  icon: Icons.person_outline,
                  title: u,
                  count: uploaderCounts[u] ?? 0,
                  onTap: () => context.push(
                    '/album/channel?v=${Uri.encodeComponent(u)}',
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: count > 0 ? Text('$count item${count == 1 ? '' : 's'}') : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({
    required this.collectionId,
    this.name,
    super.key,
  });

  final int collectionId;
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(collectionItemsProvider(collectionId));
    return Scaffold(
      appBar: AppBar(title: Text(name ?? 'Collection')),
      body: ContentBounds(
        maxWidth: 1280,
        child: items.when(
          loading: () => const MediaGridSkeleton(),
          error: (e, _) => ErrorView(
            message: 'Failed to load collection: $e',
            onRetry: () =>
                ref.invalidate(collectionItemsProvider(collectionId)),
          ),
          data: (rows) => rows.isEmpty
              ? const EmptyState(
                  icon: Icons.video_library_outlined,
                  title: 'This collection is empty',
                  message:
                      'Add items to this collection from their detail '
                      'screen.',
                )
              : MediaGrid(items: rows),
        ),
      ),
    );
  }
}
