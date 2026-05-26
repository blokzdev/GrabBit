import 'package:flutter/material.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';

/// Client-side sort of an already-loaded item list, for screens (collections,
/// smart albums) that don't re-query with a sort (P9i). Returns a new list.
List<MediaItem> sortMediaItems(List<MediaItem> items, LibrarySort sort) {
  int size(MediaItem i) => i.sizeBytes ?? 0;
  final sorted = [...items];
  switch (sort) {
    // These screens sort an already-loaded list with no FTS query, so
    // relevance has no ranking to apply → behave like newest.
    case LibrarySort.newest:
    case LibrarySort.recentlyPlayed:
    case LibrarySort.relevance:
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case LibrarySort.oldest:
      sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    case LibrarySort.titleAsc:
      sorted.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    case LibrarySort.titleDesc:
      sorted.sort(
        (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
      );
    case LibrarySort.largest:
      sorted.sort((a, b) => size(b).compareTo(size(a)));
    case LibrarySort.smallest:
      sorted.sort((a, b) => size(a).compareTo(size(b)));
  }
  return sorted;
}

/// "Sort within" app-bar menu shared by the collection-detail and smart-album
/// screens (P9i).
class GridSortButton extends StatelessWidget {
  const GridSortButton({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final LibrarySort value;
  final ValueChanged<LibrarySort> onChanged;

  static const _labels = <LibrarySort, String>{
    LibrarySort.newest: 'Newest',
    LibrarySort.oldest: 'Oldest',
    LibrarySort.titleAsc: 'Title A–Z',
    LibrarySort.titleDesc: 'Title Z–A',
    LibrarySort.largest: 'Largest',
    LibrarySort.smallest: 'Smallest',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<LibrarySort>(
      tooltip: 'Sort',
      icon: const Icon(Icons.sort),
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final entry in _labels.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
    );
  }
}
