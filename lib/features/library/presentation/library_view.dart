import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/library_filter_sheet.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';

/// The Library body (search/type filter + media grid). Hosted by HomeScreen's
/// segmented toggle; the app bar/FAB live in the shell.
class LibraryView extends ConsumerStatefulWidget {
  const LibraryView({super.key});

  @override
  ConsumerState<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends ConsumerState<LibraryView> {
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

    return ContentBounds(
      maxWidth: 1280,
      child: Column(
        children: [
          _FilterBar(
            controller: _searchController,
            filter: filter,
            onSearch: controller.setSearch,
            onType: controller.setType,
            onFilters: () => showLibraryFilters(context),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(filteredLibraryProvider),
              child: items.when(
                loading: () => const MediaGridSkeleton(),
                error: (e, _) => ErrorView(
                  message: 'Failed to load library: $e',
                  onRetry: () => ref.invalidate(filteredLibraryProvider),
                ),
                data: (rows) => rows.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.6,
                            child: EmptyState(
                              icon: filtering
                                  ? Icons.search_off
                                  : Icons.video_library_outlined,
                              title: filtering
                                  ? 'No matches'
                                  : 'Your library is empty',
                              message: filtering
                                  ? 'Try a different search or filter.'
                                  : 'Downloads will appear here.',
                              action: filtering
                                  ? null
                                  : FilledButton.icon(
                                      onPressed: () => context.push('/add'),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add'),
                                    ),
                            ),
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
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.filter,
    required this.onSearch,
    required this.onType,
    required this.onFilters,
  });

  final TextEditingController controller;
  final LibraryQuery filter;
  final ValueChanged<String> onSearch;
  final ValueChanged<String?> onType;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceMd,
        tokens.spaceSm,
        tokens.spaceMd,
        0,
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Search title or description',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: filter.search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear search',
                      onPressed: () {
                        controller.clear();
                        onSearch('');
                      },
                    ),
            ),
            onChanged: onSearch,
          ),
          SizedBox(height: tokens.spaceSm),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final type in const [
                        null,
                        'video',
                        'audio',
                        'image',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              type == null ? 'All' : _typeLabel(type),
                            ),
                            selected: filter.type == type,
                            onSelected: (_) => onType(type),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Badge(
                isLabelVisible: filter.activeFacetCount > 0,
                label: Text('${filter.activeFacetCount}'),
                child: IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Filters',
                  onPressed: onFilters,
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
