import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/library_options.dart';

// Manual providers (not riverpod_generator): the generator currently can't
// resolve Drift's generated `MediaItem` row type in a provider return
// signature (InvalidTypeException).

/// Live stream of saved library items, newest first.
final libraryItemsProvider = StreamProvider<List<MediaItem>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.mediaItems)
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
  return query.watch();
});

final mediaItemByIdProvider = FutureProvider.family<MediaItem?, String>((
  ref,
  id,
) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(
    db.mediaItems,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
});

/// Current search/filter/sort for the library grid.
class LibraryFilter extends Notifier<LibraryQuery> {
  // The sort to restore when an active search query is cleared (P10h). Set when
  // entering search (which auto-selects relevance) so clearing returns the user
  // to whatever ordering they had before.
  LibrarySort? _sortBeforeSearch;

  @override
  LibraryQuery build() => const LibraryQuery();

  void setSearch(String value) {
    final wasSearching = state.search.trim().isNotEmpty;
    final isSearching = value.trim().isNotEmpty;
    var next = state.copyWith(search: value);
    if (isSearching && !wasSearching) {
      _sortBeforeSearch = state.sort;
      next = next.copyWith(sort: LibrarySort.relevance);
    } else if (!isSearching && wasSearching) {
      // Reconcile in case the type scope narrowed during the search and the
      // sort being restored no longer applies (e.g. a duration sort).
      next = reconcile(
        next.copyWith(sort: _sortBeforeSearch ?? LibrarySort.newest),
      );
      _sortBeforeSearch = null;
    }
    state = next;
  }

  /// Adds/removes a media type from the multi-select filter (empty = all), then
  /// reconciles so a now-inapplicable sort/filter is reset (P10i).
  void toggleType(String type) {
    final next = {...state.types};
    next.contains(type) ? next.remove(type) : next.add(type);
    state = reconcile(state.copyWith(types: next));
  }

  void setTypes(Set<String> types) =>
      state = reconcile(state.copyWith(types: types));
  void setSort(LibrarySort sort) => state = state.copyWith(sort: sort);
  void setCollection(int? id) => state = state.copyWith(collectionId: () => id);
  void setSite(String? site) => state = state.copyWith(site: () => site);
  void setUploader(String? u) => state = state.copyWith(uploader: () => u);
  void setPlaylist(String? id) => state = state.copyWith(playlistId: () => id);
  void setFavoritesOnly(bool value) =>
      state = state.copyWith(favoritesOnly: value);
  void setHasTranscript(bool value) =>
      state = state.copyWith(hasTranscript: value);
  void setDurationBucket(DurationBucket? b) =>
      state = state.copyWith(durationBucket: () => b);
  void setResolutionBucket(ResolutionBucket? b) =>
      state = state.copyWith(resolutionBucket: () => b);
  void setDownloadedBucket(DateBucket? b) =>
      state = state.copyWith(downloadedBucket: () => b);
  void setUploadedBucket(DateBucket? b) =>
      state = state.copyWith(uploadedBucket: () => b);
  void clearFacets() => state = state.copyWith(
    site: () => null,
    uploader: () => null,
    playlistId: () => null,
    hasTranscript: false,
    durationBucket: () => null,
    resolutionBucket: () => null,
    downloadedBucket: () => null,
    uploadedBucket: () => null,
  );
}

final libraryFilterProvider = NotifierProvider<LibraryFilter, LibraryQuery>(
  LibraryFilter.new,
);

/// Library items filtered/sorted by [libraryFilterProvider].
final filteredLibraryProvider = StreamProvider<List<MediaItem>>((ref) {
  final query = ref.watch(libraryFilterProvider);
  return ref.watch(metadataRepositoryProvider).watchFiltered(query);
});
