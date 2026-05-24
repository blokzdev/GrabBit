import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';

/// A query-defined (auto) album: items grouped by platform, channel, or
/// recently played. Pure SQL faceting — no manual curation (P9b-2).
class SmartAlbumScreen extends ConsumerWidget {
  const SmartAlbumScreen({required this.kind, this.value, super.key});

  final String kind; // site | channel | recentPlayed
  final String? value;

  String get _title => switch (kind) {
    'site' => value ?? 'Platform',
    'channel' => value ?? 'Channel',
    _ => 'Recently played',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(
      smartAlbumItemsProvider((kind: kind, value: value)),
    );
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ContentBounds(
        maxWidth: 1280,
        child: items.when(
          loading: () => const MediaGridSkeleton(),
          error: (e, _) => ErrorView(
            message: 'Failed to load album: $e',
            onRetry: () => ref.invalidate(
              smartAlbumItemsProvider((kind: kind, value: value)),
            ),
          ),
          data: (rows) => rows.isEmpty
              ? const EmptyState(
                  icon: Icons.video_library_outlined,
                  title: 'Nothing here yet',
                  message:
                      'This album fills in as you download and play media.',
                )
              : MediaGrid(items: rows),
        ),
      ),
    );
  }
}
