import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';

void main() {
  test('LibraryQuery.activeFacetCount counts only metadata facets', () {
    expect(const LibraryQuery().activeFacetCount, 0);
    expect(
      const LibraryQuery(search: 'x', types: {'video'}).activeFacetCount,
      0,
    );
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
    'toggleType narrows to an images-only scope and clears transcript (P10i)',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(libraryFilterProvider.notifier);

      c.setHasTranscript(true);
      c.toggleType('image');
      final q = container.read(libraryFilterProvider);
      expect(q.types, {'image'});
      // Transcripts can't apply to an images-only scope → reconciled away.
      expect(q.hasTranscript, isFalse);
    },
  );

  test('toggleType adds then removes a type', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(libraryFilterProvider.notifier);

    c.toggleType('video');
    expect(container.read(libraryFilterProvider).types, {'video'});
    c.toggleType('audio');
    expect(container.read(libraryFilterProvider).types, {'video', 'audio'});
    c.toggleType('video');
    expect(container.read(libraryFilterProvider).types, {'audio'});
  });

  test(
    'narrowing to images-only resets an inapplicable duration sort (P10i-b)',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(libraryFilterProvider.notifier);

      c.setSort(LibrarySort.longest);
      c.toggleType('image');
      final q = container.read(libraryFilterProvider);
      expect(q.types, {'image'});
      // Duration sorts don't apply to images → reconciled back to newest.
      expect(q.sort, LibrarySort.newest);
    },
  );

  test(
    'clearing a search reconciles the restored sort against the type scope (P10i-b)',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(libraryFilterProvider.notifier);

      c.setSort(LibrarySort.longest);
      c.setSearch('cats'); // → relevance, remembers longest
      expect(container.read(libraryFilterProvider).sort, LibrarySort.relevance);

      // Narrow to images while searching, then clear the query.
      c.toggleType('image');
      c.setSearch('');
      final q = container.read(libraryFilterProvider);
      // The remembered duration sort no longer applies → reconciled to newest,
      // not blindly restored.
      expect(q.sort, LibrarySort.newest);
    },
  );

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
