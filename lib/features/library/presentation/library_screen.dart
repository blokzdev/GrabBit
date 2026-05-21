import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(filteredLibraryProvider);
    final filter = ref.watch(libraryFilterProvider);
    final controller = ref.read(libraryFilterProvider.notifier);
    final filtering = filter.search.isNotEmpty || filter.type != null;
    final pendingQueue =
        ref
            .watch(queueTasksProvider)
            .asData
            ?.value
            .where(
              (t) =>
                  t.status != TaskStatus.done &&
                  t.status != TaskStatus.canceled,
            )
            .length ??
        0;
    final collectionCount =
        ref.watch(collectionsProvider).asData?.value.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          PopupMenuButton<LibrarySort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: filter.sort,
            onSelected: controller.setSort,
            itemBuilder: (context) => const [
              PopupMenuItem(value: LibrarySort.newest, child: Text('Newest')),
              PopupMenuItem(value: LibrarySort.oldest, child: Text('Oldest')),
              PopupMenuItem(
                value: LibrarySort.titleAsc,
                child: Text('Title A–Z'),
              ),
              PopupMenuItem(value: LibrarySort.largest, child: Text('Largest')),
            ],
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: collectionCount > 0,
              label: Text('$collectionCount'),
              child: const Icon(Icons.folder_outlined),
            ),
            tooltip: 'Collections',
            onPressed: () => context.push('/collections'),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: pendingQueue > 0,
              label: Text('$pendingQueue'),
              child: const Icon(Icons.download_outlined),
            ),
            tooltip: 'Queue',
            onPressed: () => context.push('/queue'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            controller: _searchController,
            filter: filter,
            onSearch: controller.setSearch,
            onType: controller.setType,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(filteredLibraryProvider),
              child: items.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Failed to load library: $e')),
                data: (rows) => rows.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.6,
                            child: _EmptyLibrary(filtering: filtering),
                          ),
                        ],
                      )
                    : MediaGrid(
                        items: rows,
                        physics: const AlwaysScrollableScrollPhysics(),
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.filter,
    required this.onSearch,
    required this.onType,
  });

  final TextEditingController controller;
  final LibraryQuery filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Search title',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: filter.search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        controller.clear();
                        onSearch('');
                      },
                    ),
            ),
            onChanged: onSearch,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final type in const [null, 'video', 'audio', 'image'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(type == null ? 'All' : _typeLabel(type)),
                    selected: filter.type == type,
                    onSelected: (_) => onType(type),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _typeLabel(String type) => switch (type) {
    'video' => 'Video',
    'audio' => 'Audio',
    'image' => 'Image',
    _ => type,
  };
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.filtering});
  final bool filtering;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtering ? Icons.search_off : Icons.video_library_outlined,
            size: 72,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            filtering ? 'No matches' : 'Your library is empty',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            filtering
                ? 'Try a different search or filter.'
                : 'Downloads will appear here.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
