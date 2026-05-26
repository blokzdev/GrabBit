import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';

void main() {
  test('LibraryQuery.activeFacetCount counts only metadata facets', () {
    expect(const LibraryQuery().activeFacetCount, 0);
    expect(const LibraryQuery(search: 'x', type: 'video').activeFacetCount, 0);
    expect(
      const LibraryQuery(site: 'youtube', uploader: 'Rick').activeFacetCount,
      2,
    );
    // The has-transcript filter counts as an active facet (P10h).
    expect(
      const LibraryQuery(site: 'youtube', hasTranscript: true).activeFacetCount,
      2,
    );
  });

  test('facet setters update and clearFacets resets them', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(libraryFilterProvider.notifier);

    c.setSite('tiktok');
    c.setUploader('Rick');
    c.setPlaylist('PL1');
    c.setHasTranscript(true);
    var q = container.read(libraryFilterProvider);
    expect([q.site, q.uploader, q.playlistId], ['tiktok', 'Rick', 'PL1']);
    expect(q.hasTranscript, isTrue);
    expect(q.activeFacetCount, 4);

    // Setting a facet back to null clears just that one.
    c.setSite(null);
    expect(container.read(libraryFilterProvider).site, isNull);

    c.clearFacets();
    q = container.read(libraryFilterProvider);
    expect([q.site, q.uploader, q.playlistId], [null, null, null]);
    expect(q.hasTranscript, isFalse);
  });

  test(
    'entering a search auto-selects relevance, clearing restores it (P10h)',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(libraryFilterProvider.notifier);

      // Start from a non-default sort.
      c.setSort(LibrarySort.titleAsc);
      c.setSearch('cats');
      var q = container.read(libraryFilterProvider);
      expect(q.search, 'cats');
      expect(q.sort, LibrarySort.relevance);

      // The user can override the sort while searching; refining the query keeps it.
      c.setSort(LibrarySort.largest);
      c.setSearch('cats and dogs');
      expect(container.read(libraryFilterProvider).sort, LibrarySort.largest);

      // Clearing the query restores the pre-search sort.
      c.setSearch('');
      q = container.read(libraryFilterProvider);
      expect(q.search, '');
      expect(q.sort, LibrarySort.titleAsc);
    },
  );
}
