import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';

/// Opens the Library facet filters (platform / channel / playlist) as a sheet.
Future<void> showLibraryFilters(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => const _LibraryFilterSheet(),
);

class _LibraryFilterSheet extends ConsumerWidget {
  const _LibraryFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filter = ref.watch(libraryFilterProvider);
    final controller = ref.read(libraryFilterProvider.notifier);
    final sites = ref.watch(distinctSitesProvider).asData?.value ?? const [];
    final uploaders =
        ref.watch(distinctUploadersProvider).asData?.value ?? const [];
    final playlists =
        ref.watch(distinctPlaylistsProvider).asData?.value ?? const [];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Filters', style: theme.textTheme.titleLarge),
                ),
                if (filter.activeFacetCount > 0)
                  TextButton(
                    onPressed: controller.clearFacets,
                    child: const Text('Clear all'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (sites.isNotEmpty) ...[
              Text('Platform', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in sites)
                    FilterChip(
                      label: Text(s),
                      selected: filter.site == s,
                      onSelected: (sel) => controller.setSite(sel ? s : null),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (uploaders.isNotEmpty) ...[
              _FacetDropdown(
                label: 'Channel',
                value: filter.uploader,
                options: {for (final u in uploaders) u: u},
                onChanged: controller.setUploader,
              ),
              const SizedBox(height: 16),
            ],
            if (playlists.isNotEmpty)
              _FacetDropdown(
                label: 'Playlist',
                value: filter.playlistId,
                options: {for (final p in playlists) p.id: p.title},
                onChanged: controller.setPlaylist,
              ),
            if (sites.isEmpty && uploaders.isEmpty && playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No filters yet — download some media first.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FacetDropdown extends StatelessWidget {
  const _FacetDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final Map<String, String> options; // value → display
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All')),
        for (final entry in options.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
