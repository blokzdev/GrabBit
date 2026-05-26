import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/brand_badge.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/library_options.dart';
import 'package:grabbit/features/library/presentation/explorer_view.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/library_view.dart';

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
    final tokens = GrabBitTokens.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const _BrandTitle(),
        actions: [if (library) const _SortAction()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spaceMd,
              0,
              tokens.spaceMd,
              tokens.spaceSm,
            ),
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

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandBadge(),
        SizedBox(width: tokens.spaceSm),
        Text('GrabBit', style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _SortAction extends ConsumerWidget {
  const _SortAction();

  // Sorts offered in the library menu, in display order. Relevance is gated on
  // an active query; the rest are gated by type-applicability (P10i).
  static const _labels = <LibrarySort, String>{
    LibrarySort.relevance: 'Relevance',
    LibrarySort.newest: 'Newest',
    LibrarySort.oldest: 'Oldest',
    LibrarySort.uploadNewest: 'Newest uploaded',
    LibrarySort.uploadOldest: 'Oldest uploaded',
    LibrarySort.recentlyPlayed: 'Recently played',
    LibrarySort.longest: 'Longest',
    LibrarySort.shortest: 'Shortest',
    LibrarySort.titleAsc: 'Title A–Z',
    LibrarySort.titleDesc: 'Title Z–A',
    LibrarySort.largest: 'Largest',
    LibrarySort.smallest: 'Smallest',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(libraryFilterProvider);
    final searching = filter.search.trim().isNotEmpty;
    return PopupMenuButton<LibrarySort>(
      icon: const Icon(Icons.sort),
      tooltip: 'Sort',
      initialValue: filter.sort,
      onSelected: ref.read(libraryFilterProvider.notifier).setSort,
      itemBuilder: (context) => [
        for (final entry in _labels.entries)
          if (entry.key == LibrarySort.relevance
              ? searching
              : sortVisible(entry.key, filter.types))
            PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
    );
  }
}
