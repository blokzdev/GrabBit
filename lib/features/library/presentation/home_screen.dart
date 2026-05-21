import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/explorer_view.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/library_view.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';

enum HomeView { library, explorer }

/// App home: a Library | Explorer segmented toggle over two views of the same
/// on-device media. The Library filters by collections/tags/facets; the
/// Explorer browses the virtual folder tree.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  HomeView _view = HomeView.library;

  @override
  Widget build(BuildContext context) {
    final library = _view == HomeView.library;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('GrabBit'),
        actions: [
          if (library) ...[const _SortAction(), const _CollectionsAction()],
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SegmentedButton<HomeView>(
              segments: const [
                ButtonSegment(
                  value: HomeView.library,
                  icon: Icon(Icons.video_library_outlined),
                  label: Text('Library'),
                ),
                ButtonSegment(
                  value: HomeView.explorer,
                  icon: Icon(Icons.folder_outlined),
                  label: Text('Explorer'),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
          ),
        ),
      ),
      body: library ? const LibraryView() : const ExplorerView(),
      floatingActionButton: library
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/add'),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            )
          : FloatingActionButton.extended(
              onPressed: () => createFolderFlow(context, ref),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('New folder'),
            ),
    );
  }
}

class _SortAction extends ConsumerWidget {
  const _SortAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(libraryFilterProvider);
    return PopupMenuButton<LibrarySort>(
      icon: const Icon(Icons.sort),
      tooltip: 'Sort',
      initialValue: filter.sort,
      onSelected: ref.read(libraryFilterProvider.notifier).setSort,
      itemBuilder: (context) => const [
        PopupMenuItem(value: LibrarySort.newest, child: Text('Newest')),
        PopupMenuItem(value: LibrarySort.oldest, child: Text('Oldest')),
        PopupMenuItem(value: LibrarySort.titleAsc, child: Text('Title A–Z')),
        PopupMenuItem(value: LibrarySort.largest, child: Text('Largest')),
      ],
    );
  }
}

class _CollectionsAction extends ConsumerWidget {
  const _CollectionsAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(collectionsProvider).asData?.value.length ?? 0;
    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.collections_bookmark_outlined),
      ),
      tooltip: 'Collections',
      onPressed: () => context.push('/collections'),
    );
  }
}
