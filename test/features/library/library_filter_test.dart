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
  });

  test('facet setters update and clearFacets resets them', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(libraryFilterProvider.notifier);

    c.setSite('tiktok');
    c.setUploader('Rick');
    c.setPlaylist('PL1');
    var q = container.read(libraryFilterProvider);
    expect([q.site, q.uploader, q.playlistId], ['tiktok', 'Rick', 'PL1']);
    expect(q.activeFacetCount, 3);

    // Setting a facet back to null clears just that one.
    c.setSite(null);
    expect(container.read(libraryFilterProvider).site, isNull);

    c.clearFacets();
    q = container.read(libraryFilterProvider);
    expect([q.site, q.uploader, q.playlistId], [null, null, null]);
  });
}
