import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/library_options.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';

/// Opens the Library filters (ranges · quality · date · facets) as a sheet.
Future<void> showLibraryFilters(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => const _LibraryFilterSheet(),
);

const _durationLabels = {
  DurationBucket.underMin: 'Under 1 min',
  DurationBucket.oneToFive: '1–5 min',
  DurationBucket.fiveToTwenty: '5–20 min',
  DurationBucket.twentyToHour: '20–60 min',
  DurationBucket.overHour: 'Over 1 hour',
};

const _resolutionLabels = {
  ResolutionBucket.sd: 'SD',
  ResolutionBucket.hd: '720p',
  ResolutionBucket.fullHd: '1080p',
  ResolutionBucket.uhd: '4K',
};

const _dateLabels = {
  DateBucket.today: 'Today',
  DateBucket.last7: 'Last 7 days',
  DateBucket.last30: 'Last 30 days',
  DateBucket.thisYear: 'This year',
};

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
    final tags = ref.watch(distinctTagsProvider).asData?.value ?? const [];
    final noFacets =
        sites.isEmpty && uploaders.isEmpty && playlists.isEmpty && tags.isEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
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
              // Duration & resolution only apply to certain media types; hide
              // them (and reconcile any active bucket) for non-applicable scopes.
              if (durationApplies(filter.types))
                _Section(
                  title: 'Duration',
                  child: _BucketChips<DurationBucket>(
                    values: DurationBucket.values,
                    label: (b) => _durationLabels[b]!,
                    selected: filter.durationBucket,
                    onChanged: controller.setDurationBucket,
                  ),
                ),
              if (resolutionApplies(filter.types))
                _Section(
                  title: 'Resolution',
                  child: _BucketChips<ResolutionBucket>(
                    values: ResolutionBucket.values,
                    label: (b) => _resolutionLabels[b]!,
                    selected: filter.resolutionBucket,
                    onChanged: controller.setResolutionBucket,
                  ),
                ),
              _Section(
                title: 'Downloaded',
                child: _BucketChips<DateBucket>(
                  values: DateBucket.values,
                  label: (b) => _dateLabels[b]!,
                  selected: filter.downloadedBucket,
                  onChanged: controller.setDownloadedBucket,
                ),
              ),
              _Section(
                title: 'Uploaded',
                child: _BucketChips<DateBucket>(
                  values: DateBucket.values,
                  label: (b) => _dateLabels[b]!,
                  selected: filter.uploadedBucket,
                  onChanged: controller.setUploadedBucket,
                ),
              ),
              if (transcriptApplies(filter.types))
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Has transcript'),
                  subtitle: const Text('Only items with extracted captions'),
                  value: filter.hasTranscript,
                  onChanged: controller.setHasTranscript,
                ),
              if (sites.isNotEmpty)
                _Section(
                  title: 'Platform',
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final s in sites)
                        FilterChip(
                          label: Text(s),
                          selected: filter.site == s,
                          onSelected: (sel) =>
                              controller.setSite(sel ? s : null),
                        ),
                    ],
                  ),
                ),
              if (uploaders.isNotEmpty) ...[
                const SizedBox(height: 8),
                _FacetDropdown(
                  label: 'Channel',
                  value: filter.uploader,
                  options: {for (final u in uploaders) u: u},
                  onChanged: controller.setUploader,
                ),
              ],
              if (playlists.isNotEmpty) ...[
                const SizedBox(height: 16),
                _FacetDropdown(
                  label: 'Playlist',
                  value: filter.playlistId,
                  options: {for (final p in playlists) p.id: p.title},
                  onChanged: controller.setPlaylist,
                ),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                _FacetDropdown(
                  label: 'Tag',
                  value: filter.tag,
                  options: {for (final t in tags) t: t},
                  onChanged: controller.setTag,
                ),
              ],
              if (noFacets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No platform/channel filters yet — download some media first.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled filter section: title + content with consistent spacing.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Single-select chip group: tapping the active chip clears the selection.
class _BucketChips<T> extends StatelessWidget {
  const _BucketChips({
    required this.values,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final String Function(T) label;
  final T? selected;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final v in values)
          FilterChip(
            label: Text(label(v)),
            selected: selected == v,
            onSelected: (sel) => onChanged(sel ? v : null),
          ),
      ],
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
