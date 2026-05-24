import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/share/external_share_service.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/grid_sort.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';

/// A query-defined (auto) album: items grouped by platform, channel, or
/// recently played. Pure SQL faceting — no manual curation (P9b-2).
class SmartAlbumScreen extends ConsumerStatefulWidget {
  const SmartAlbumScreen({required this.kind, this.value, super.key});

  final String kind; // site | channel | recentPlayed
  final String? value;

  @override
  ConsumerState<SmartAlbumScreen> createState() => _SmartAlbumScreenState();
}

class _SmartAlbumScreenState extends ConsumerState<SmartAlbumScreen> {
  LibrarySort _sort = LibrarySort.newest;

  String get _title => switch (widget.kind) {
    'site' => widget.value ?? 'Platform',
    'channel' => widget.value ?? 'Channel',
    _ => 'Recently played',
  };

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(
      smartAlbumItemsProvider((kind: widget.kind, value: widget.value)),
    );
    final rows = items.asData?.value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (rows.isNotEmpty) ...[
            GridSortButton(
              value: _sort,
              onChanged: (s) => setState(() => _sort = s),
            ),
            IconButton(
              tooltip: 'Share all',
              icon: const Icon(Icons.ios_share),
              onPressed: () => ref
                  .read(externalShareServiceProvider)
                  .shareFiles([for (final r in rows) r.filePath]),
            ),
          ],
        ],
      ),
      body: ContentBounds(
        maxWidth: 1280,
        child: items.when(
          loading: () => const MediaGridSkeleton(),
          error: (e, _) => ErrorView(
            message: 'Failed to load album: $e',
            onRetry: () => ref.invalidate(
              smartAlbumItemsProvider((kind: widget.kind, value: widget.value)),
            ),
          ),
          data: (rows) => rows.isEmpty
              ? const EmptyState(
                  icon: Icons.video_library_outlined,
                  title: 'Nothing here yet',
                  message:
                      'This album fills in as you download and play media.',
                )
              : MediaGrid(items: sortMediaItems(rows, _sort)),
        ),
      ),
    );
  }
}
