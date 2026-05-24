import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/download_error.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/duration_format.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_banner.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/downloader/presentation/downloader_controller.dart';
import 'package:grabbit/features/downloader/presentation/error_messages.dart';
import 'package:grabbit/features/downloader/presentation/link_support.dart';
import 'package:grabbit/features/downloader/presentation/selection_controller.dart';

/// Thumbnail picker for an expanded playlist/channel/carousel.
class SelectionScreen extends ConsumerWidget {
  const SelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(selectionControllerProvider);
    final controller = ref.read(selectionControllerProvider.notifier);
    final entries = state.allEntries;
    final visible = state.hideSaved
        ? entries.where((e) => !state.savedUrls.contains(e.url)).toList()
        : entries;
    final selectedCount = state.selected.length;
    final tokens = GrabBitTokens.of(context);

    final Widget body;
    if (state.expanding && entries.isEmpty) {
      body = const MediaGridSkeleton();
    } else if (entries.isEmpty) {
      body = const EmptyState(
        icon: Icons.playlist_remove,
        title: 'Nothing to download',
        message: 'These links produced no downloadable items.',
      );
    } else if (visible.isEmpty) {
      body = const EmptyState(
        icon: Icons.library_add_check_outlined,
        title: 'All already in your library',
        message: 'Turn off "Hide already-saved" to download them again.',
      );
    } else {
      body = GridView.builder(
        padding: EdgeInsets.all(tokens.spaceMd),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.8,
          crossAxisSpacing: tokens.spaceSm,
          mainAxisSpacing: tokens.spaceSm,
        ),
        itemCount: visible.length,
        itemBuilder: (context, i) => _EntryTile(
          entry: visible[i],
          selected: state.selected.contains(visible[i].url),
          saved: state.savedUrls.contains(visible[i].url),
          onTap: () => controller.toggle(visible[i].url),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Select items ($selectedCount/${state.totalCount})'),
        actions: [
          if (state.hasSaved)
            IconButton(
              icon: Icon(
                state.hideSaved ? Icons.visibility_off : Icons.visibility,
              ),
              tooltip: state.hideSaved ? 'Show saved' : 'Hide already-saved',
              isSelected: state.hideSaved,
              onPressed: () => controller.setHideSaved(!state.hideSaved),
            ),
          TextButton(
            onPressed: entries.isEmpty || selectedCount == entries.length
                ? null
                : controller.selectAll,
            child: const Text('All'),
          ),
          TextButton(
            onPressed: selectedCount == 0 ? null : controller.selectNone,
            child: const Text('None'),
          ),
        ],
      ),
      body: ContentBounds(
        maxWidth: 1280,
        child: Column(
          children: [
            for (final s in state.sources.where((s) => s.error != null))
              Padding(
                padding: EdgeInsets.fromLTRB(
                  tokens.spaceMd,
                  tokens.spaceMd,
                  tokens.spaceMd,
                  0,
                ),
                child: _sourceErrorBanner(s),
              ),
            Expanded(child: body),
            _BottomBar(preset: state.preset, hasSelection: selectedCount > 0),
          ],
        ),
      ),
    );
  }
}

/// Per-URL banner for a multi-link paste: an unsupported link reads as an
/// info-toned notice with platform-aware guidance; a real error keeps the error
/// tone. Both keep the raw message under Details.
Widget _sourceErrorBanner(ExpandedSource s) {
  if (s.errorCode == DownloadErrorCode.unsupportedSite) {
    final info = describeUnsupportedLink(s.url, rawError: s.error);
    return ErrorBanner(
      tone: BannerTone.notice,
      message: '${s.url}\n${info.message}',
      details: s.error,
    );
  }
  return ErrorBanner(
    message: '${s.url}\n${friendlyError(s.errorCode, s.error!)}',
    details: s.error,
  );
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.selected,
    required this.onTap,
    this.saved = false,
  });
  final MediaEntry entry;
  final bool selected;
  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    final radius = BorderRadius.circular(tokens.radiusMd);
    final duration = formatDuration(entry.durationSec);

    return Semantics(
      button: true,
      selected: selected,
      label: entry.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: selected
                      ? Border.all(color: scheme.primary, width: 2)
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _EntryThumb(entry: entry),
                      Positioned(
                        top: tokens.spaceXs,
                        left: tokens.spaceXs,
                        child: _SelectionBadge(selected: selected),
                      ),
                      if (saved)
                        Positioned(
                          top: tokens.spaceXs,
                          right: tokens.spaceXs,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: tokens.spaceSm,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.tertiary.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(
                                tokens.radiusSm,
                              ),
                            ),
                            child: Text(
                              'Saved',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onTertiary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: tokens.spaceXs),
            Text(
              entry.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            if (duration.isNotEmpty)
              Text(
                duration,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntryThumb extends StatelessWidget {
  const _EntryThumb({required this.entry});
  final MediaEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        entry.isImage ? Icons.image_outlined : Icons.movie_outlined,
        color: scheme.onSurfaceVariant,
        size: 36,
      ),
    );
    final thumb = entry.thumbnailUrl;
    if (thumb == null) return placeholder;
    return Image.network(
      thumb,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

/// Selection check for an entry; legible on a themed placeholder or a photo via
/// a small scrim disc behind the glyph.
class _SelectionBadge extends StatelessWidget {
  const _SelectionBadge({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.scrim.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(1),
      child: Icon(
        selected ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 20,
        color: selected ? scheme.primary : Colors.white,
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.preset, required this.hasSelection});
  final QualityPreset preset;
  final bool hasSelection;

  Future<void> _finish(
    BuildContext context,
    Future<void> Function() action,
    bool startNow,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    await action();
    router.go('/');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(startNow ? 'Downloads started' : 'Added to queue'),
          action: SnackBarAction(
            label: 'View queue',
            onPressed: () => router.go('/queue'),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final controller = ref.read(selectionControllerProvider.notifier);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('Quality', style: theme.textTheme.labelLarge),
                  SizedBox(width: tokens.spaceMd),
                  DropdownButton<QualityPreset>(
                    value: preset,
                    onChanged: (p) =>
                        p == null ? null : controller.setPreset(p),
                    items: [
                      for (final p in QualityPreset.values)
                        DropdownMenuItem(value: p, child: Text(p.label)),
                    ],
                  ),
                ],
              ),
              SizedBox(height: tokens.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: hasSelection
                          ? () => _finish(context, controller.addToBatch, false)
                          : null,
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Add to queue'),
                    ),
                  ),
                  SizedBox(width: tokens.spaceMd),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.accent,
                        foregroundColor: tokens.onAccent,
                      ),
                      onPressed: hasSelection
                          ? () => _finish(context, controller.downloadNow, true)
                          : null,
                      icon: const Icon(Icons.download),
                      label: const Text('Download now'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
