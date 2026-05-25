import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/share/external_share_service.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/async_fade.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/dedupe_actions.dart';
import 'package:grabbit/features/library/presentation/grid_sort.dart';
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
    return AsyncFade(
      value: collections,
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
      trailing: PopupMenuButton<String>(
        tooltip: 'More',
        onSelected: (value) async {
          final repo = ref.read(metadataRepositoryProvider);
          if (value == 'rename') {
            final name = await _promptName(context, collection.name);
            if (name == null) return;
            await repo.renameCollection(collection.id, name);
            if (context.mounted) _notify(context, 'Renamed');
          } else {
            final ok = await confirm(
              context,
              title: 'Delete collection?',
              message:
                  'Delete "${collection.name}"? The media stays in your '
                  'library.',
              confirmLabel: 'Delete',
              destructive: true,
            );
            if (!ok) return;
            await repo.deleteCollection(collection.id);
            if (context.mounted) _notify(context, 'Collection deleted');
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      onTap: () =>
          context.push('/collection/${collection.id}', extra: collection.name),
    );
  }

  Future<String?> _promptName(BuildContext context, String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.of(dialogContext).pop(v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.of(dialogContext).pop(v);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
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
    final dupGroups =
        ref.watch(duplicatesProvider).asData?.value ??
        const <List<MediaItem>>[];

    return AsyncFade(
      value: sites,
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
            if (dupGroups.isNotEmpty) _DuplicatesCard(groups: dupGroups),
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

/// A distinct, actionable maintenance card for exact duplicates — shown only
/// when duplicates exist. **Review** opens the detail/cleanup screen; **Clean
/// up** bulk-removes the extra copies (keeping the oldest of each group). Pure
/// Drift — present on every device, no embedder needed.
class _DuplicatesCard extends ConsumerWidget {
  const _DuplicatesCard({required this.groups});
  final List<List<MediaItem>> groups;

  Future<void> _cleanUp(BuildContext context, WidgetRef ref) async {
    final n = duplicatesToRemove(groups).length;
    if (n == 0) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirm(
      context,
      title: 'Remove duplicate copies?',
      message:
          'Keeps the oldest in each group and permanently deletes the other '
          '$n cop${n == 1 ? 'y' : 'ies'}. This cannot be undone.',
      confirmLabel: 'Remove $n',
      destructive: true,
    );
    if (!ok) return;
    final removed = await resolveDuplicates(ref);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed $removed cop${removed == 1 ? 'y' : 'ies'}'),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    final extra = duplicatesToRemove(groups).length;
    return Card(
      margin: EdgeInsets.only(bottom: tokens.spaceMd),
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.content_copy_outlined,
                  color: scheme.onTertiaryContainer,
                ),
                SizedBox(width: tokens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Duplicates',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                      Text(
                        '${groups.length} group${groups.length == 1 ? '' : 's'} · '
                        '$extra extra cop${extra == 1 ? 'y' : 'ies'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spaceSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => context.push('/duplicates'),
                  child: const Text('Review'),
                ),
                SizedBox(width: tokens.spaceSm),
                FilledButton.tonalIcon(
                  onPressed: () => _cleanUp(context, ref),
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: const Text('Clean up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class CollectionDetailScreen extends ConsumerStatefulWidget {
  const CollectionDetailScreen({
    required this.collectionId,
    this.name,
    super.key,
  });

  final int collectionId;
  final String? name;

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState
    extends ConsumerState<CollectionDetailScreen> {
  LibrarySort _sort = LibrarySort.newest;
  late String _name = widget.name ?? 'Collection';

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(collectionItemsProvider(widget.collectionId));
    final rows = items.asData?.value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          if (rows.isNotEmpty)
            GridSortButton(
              value: _sort,
              onChanged: (s) => setState(() => _sort = s),
            ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) => switch (value) {
              'rename' => _rename(),
              'share' => ref.read(externalShareServiceProvider).shareFiles([
                for (final r in rows) r.filePath,
              ]),
              _ => _delete(),
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              if (rows.isNotEmpty)
                const PopupMenuItem(value: 'share', child: Text('Share all')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ContentBounds(
        maxWidth: 1280,
        child: AsyncFade(
          value: items,
          loading: () => const MediaGridSkeleton(),
          error: (e, _) => ErrorView(
            message: 'Failed to load collection: $e',
            onRetry: () =>
                ref.invalidate(collectionItemsProvider(widget.collectionId)),
          ),
          data: (rows) => rows.isEmpty
              ? const EmptyState(
                  icon: Icons.video_library_outlined,
                  title: 'This collection is empty',
                  message:
                      'Add items to this collection from their detail '
                      'screen.',
                )
              : MediaGrid(items: sortMediaItems(rows, _sort)),
        ),
      ),
    );
  }

  Future<void> _rename() async {
    final name = await _promptCollectionName(context, _name);
    if (name == null) return;
    await ref
        .read(metadataRepositoryProvider)
        .renameCollection(widget.collectionId, name);
    if (mounted) setState(() => _name = name);
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final ok = await confirm(
      context,
      title: 'Delete collection?',
      message: 'Delete "$_name"? The media stays in your library.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await ref
        .read(metadataRepositoryProvider)
        .deleteCollection(widget.collectionId);
    if (router.canPop()) router.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Collection deleted')));
  }
}

Future<String?> _promptCollectionName(BuildContext context, String initial) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Rename collection'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Name'),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.of(dialogContext).pop(v.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final v = controller.text.trim();
            if (v.isNotEmpty) Navigator.of(dialogContext).pop(v);
          },
          child: const Text('Rename'),
        ),
      ],
    ),
  );
}
