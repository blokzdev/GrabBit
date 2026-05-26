import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/graph/graph_store_provider.dart';
import 'package:grabbit/core/text/textrank.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/byte_format.dart';
import 'package:grabbit/core/utils/duration_format.dart';
import 'package:grabbit/core/utils/subtitle_files.dart';
import 'package:grabbit/core/widgets/async_fade.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/core/share/external_share_service.dart';
import 'package:grabbit/features/library/data/library_repository.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/data/transcript_service.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/media_actions.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';
import 'package:grabbit/features/library/presentation/related_provider.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:video_player/video_player.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(mediaItemByIdProvider(itemId));
    final row = item.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(row?.title ?? 'Item'),
        actions: [
          if (row != null) ...[
            IconButton(
              icon: AnimatedSwitcher(
                duration: GrabBitTokens.of(context).motionShort,
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  row.isFavorite ? Icons.star : Icons.star_outline,
                  key: ValueKey(row.isFavorite),
                ),
              ),
              tooltip: row.isFavorite ? 'Unfavorite' : 'Favorite',
              onPressed: () async {
                await ref
                    .read(metadataRepositoryProvider)
                    .toggleFavorite(itemId, !row.isFavorite);
                ref.invalidate(mediaItemByIdProvider(itemId));
              },
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) async {
                switch (value) {
                  case 'save':
                    await saveItems(context, ref, [row]);
                  case 'move':
                    await moveItemsTo(context, ref, [row]);
                  case 'studio':
                    await context.push('/item/$itemId/studio');
                  case 'graph':
                    await context.push('/item/$itemId/graph');
                  case 'edit':
                    await context.push('/item/$itemId/edit');
                  case 'transcript':
                    await _buildTranscript(context, ref, row);
                  case 'share':
                    await shareItems(ref, [row]);
                  case 'copy':
                    await copyUrl(context, [row]);
                  case 'open':
                    await ref
                        .read(externalShareServiceProvider)
                        .openUrl(row.sourceUrl);
                  case 'delete':
                    await _deleteAndPop(context, ref, row);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'save',
                  child: Text('Save to device'),
                ),
                const PopupMenuItem(
                  value: 'move',
                  child: Text('Move to folder'),
                ),
                const PopupMenuItem(
                  value: 'studio',
                  child: Text('Edit in Studio'),
                ),
                if (ref.watch(graphStoreProvider).isAvailable)
                  const PopupMenuItem(
                    value: 'graph',
                    child: Text('View in graph'),
                  ),
                const PopupMenuItem(value: 'edit', child: Text('Edit info')),
                const PopupMenuItem(
                  value: 'transcript',
                  child: Text('Build transcript'),
                ),
                const PopupMenuItem(value: 'share', child: Text('Share file')),
                const PopupMenuItem(
                  value: 'copy',
                  child: Text('Copy source URL'),
                ),
                const PopupMenuItem(
                  value: 'open',
                  child: Text('Open source link'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ],
      ),
      body: ContentBounds(
        child: AsyncFade(
          value: item,
          loading: () => const _DetailSkeleton(),
          error: (e, _) => ErrorView(
            message: 'Failed to load item: $e',
            onRetry: () => ref.invalidate(mediaItemByIdProvider(itemId)),
          ),
          data: (row) => row == null
              ? const EmptyState(
                  icon: Icons.broken_image_outlined,
                  title: 'Item not found',
                  message: 'This item may have been removed.',
                )
              : _ItemBody(item: row),
        ),
      ),
    );
  }
}

/// Confirms, deletes the item (honoring the secure-delete setting), then pops
/// the detail screen — keeping the detail-screen delete distinct from the
/// grid menu's `deleteItems` (which stays on the list).
Future<void> _deleteAndPop(
  BuildContext context,
  WidgetRef ref,
  MediaItem row,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final ok = await confirm(
    context,
    title: 'Delete this item?',
    message:
        'Permanently removes the downloaded file from GrabBit. This cannot be '
        'undone.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!ok) return;
  final secure =
      ref.read(settingsControllerProvider).asData?.value.secureDelete ?? false;
  await ref.read(libraryRepositoryProvider).deleteItem(row, secure: secure);
  if (router.canPop()) router.pop();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Deleted')));
}

class _ItemBody extends StatelessWidget {
  const _ItemBody({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    return ListView(
      children: [
        Hero(
          tag: mediaHeroTag(item.id),
          // The destination hosts the heavy player/zoomable image; fly the
          // lightweight thumbnail instead so the transition stays smooth.
          flightShuttleBuilder: (_, _, _, _, _) => MediaThumb(item: item),
          child: ColoredBox(
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: item.type == 'image'
                  ? InteractiveViewer(
                      child: Image.file(
                        File(item.filePath),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const _BrokenMedia(),
                      ),
                    )
                  : _PlayerView(itemId: item.id, filePath: item.filePath),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(tokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: theme.textTheme.headlineSmall),
              SizedBox(height: tokens.spaceXs),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InkWell(
                    onTap: () =>
                        _openHub(context, 'site', item.site, item.site),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    child: Text(
                      item.site,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '  ·  Saved ${_ymd(item.createdAt.toLocal())}'
                    '${item.lastAccessedAt != null ? '  ·  Last played ${_ymd(item.lastAccessedAt!.toLocal())}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              _DetailChips(item: item),
              _SummarySection(itemId: item.id),
              _MetadataSection(itemId: item.id),
              _TranscriptSection(itemId: item.id, mediaPath: item.filePath),
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                SizedBox(height: tokens.spaceMd),
                Text(item.notes!, style: theme.textTheme.bodyMedium),
              ],
              _TagsRow(itemId: item.id),
              _CollectionsRow(itemId: item.id),
              SizedBox(height: tokens.spaceLg),
              _ExportButton(item: item),
              _RelatedSection(itemId: item.id),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens the entity hub listing every item for [type]/[value] (uploader, site,
/// playlist, or tag). [value] is the filter key; [name] the display label.
void _openHub(BuildContext context, String type, String value, String name) =>
    context.push(
      Uri(path: '/hub/$type', queryParameters: {'v': value}).toString(),
      extra: name,
    );

/// "More like this" — a horizontal carousel of related items (graph + vector).
/// Renders nothing until results arrive (or when the graph is unavailable), so
/// it never adds empty chrome to the detail screen.
class _RelatedSection extends ConsumerWidget {
  const _RelatedSection({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final related =
        ref.watch(relatedItemsProvider(itemId)).asData?.value ?? const [];
    if (related.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('More like this', style: theme.textTheme.titleMedium),
          SizedBox(height: tokens.spaceSm),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: related.length,
              separatorBuilder: (_, _) => SizedBox(width: tokens.spaceMd),
              itemBuilder: (_, i) => _RelatedCard(item: related[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final radius = BorderRadius.circular(tokens.radiusMd);
    return SizedBox(
      width: 150,
      child: InkWell(
        onTap: () => context.push('/item/${item.id}'),
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: radius,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MediaThumb(item: item),
                    if (item.type == 'video')
                      Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.scrim.withValues(
                              alpha: 0.4,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: tokens.spaceXs),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Quick technical facts (type / duration / resolution / size) as tonal chips.
class _DetailChips extends StatelessWidget {
  const _DetailChips({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final resolution = (item.width != null && item.height != null)
        ? '${item.width}×${item.height}'
        : '';
    final chips = [
      item.type.toUpperCase(),
      formatDuration(item.durationSec),
      resolution,
      formatBytes(item.sizeBytes),
    ].where((e) => e.isNotEmpty).toList();
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceMd),
      child: Wrap(
        spacing: tokens.spaceSm,
        runSpacing: tokens.spaceXs,
        children: [for (final c in chips) _chip(context, c)],
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceMd,
        vertical: tokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Uploader / username / playlist / upload date + an expandable description,
/// from the metadata captured at download time.
/// Extractive TextRank summary (P10e) for an item's text. Memoized per item;
/// recomputes whenever the item's metadata changes. Prefers the captured
/// transcript (P10f) and falls back to the description; because it watches the
/// metadata, the summary recomputes the instant a transcript is written.
final itemSummaryProvider = Provider.family<List<String>, String>((
  ref,
  itemId,
) {
  final meta = ref.watch(metadataForItemProvider(itemId)).asData?.value;
  final text = meta?.transcript ?? meta?.description;
  if (text == null || text.trim().isEmpty) return const [];
  return summarize(text);
});

/// A short extractive TL;DR shown above the full metadata/description. Hidden
/// when there's nothing worth condensing (short or absent text).
class _SummarySection extends ConsumerWidget {
  const _SummarySection({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final sentences = ref.watch(itemSummaryProvider(itemId));
    if (sentences.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Summary', style: theme.textTheme.titleSmall),
          SizedBox(height: tokens.spaceXs),
          for (final s in sentences)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.spaceXs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: theme.textTheme.bodyMedium),
                  Expanded(child: Text(s, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Manual "Build transcript" action (P10f): extracts text from the item's
/// caption sidecars and stores it, so the summary and transcript view update.
Future<void> _buildTranscript(
  BuildContext context,
  WidgetRef ref,
  MediaItem row,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final transcript = await ref
      .read(transcriptServiceProvider)
      .extractTranscript(row.filePath);
  if (transcript == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No caption files found for this item')),
    );
    return;
  }
  await ref
      .read(metadataRepositoryProvider)
      .updateTranscript(row.id, transcript);
  messenger.showSnackBar(const SnackBar(content: Text('Transcript built')));
}

/// The stored transcript (P10f) in an expandable block. Hidden when there's no
/// transcript; when "backfill on open" is enabled it builds one once from any
/// caption sidecars the first time the item is opened.
class _TranscriptSection extends ConsumerStatefulWidget {
  const _TranscriptSection({required this.itemId, required this.mediaPath});
  final String itemId;
  final String mediaPath;

  @override
  ConsumerState<_TranscriptSection> createState() => _TranscriptSectionState();
}

class _TranscriptSectionState extends ConsumerState<_TranscriptSection> {
  bool _backfillAttempted = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final meta = ref
        .watch(metadataForItemProvider(widget.itemId))
        .asData
        ?.value;
    final backfillOn =
        ref
            .watch(settingsControllerProvider)
            .asData
            ?.value
            .transcriptBackfill ??
        false;
    final transcript = meta?.transcript;

    if (transcript == null || transcript.trim().isEmpty) {
      if (backfillOn && !_backfillAttempted) {
        _backfillAttempted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _runBackfill());
      }
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transcript', style: theme.textTheme.titleSmall),
          SizedBox(height: tokens.spaceXs),
          _ExpandableText(text: transcript),
        ],
      ),
    );
  }

  Future<void> _runBackfill() async {
    final transcript = await ref
        .read(transcriptServiceProvider)
        .extractTranscript(widget.mediaPath);
    if (transcript == null || !mounted) return;
    await ref
        .read(metadataRepositoryProvider)
        .updateTranscript(widget.itemId, transcript);
  }
}

class _MetadataSection extends ConsumerWidget {
  const _MetadataSection({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final meta = ref.watch(metadataForItemProvider(itemId)).asData?.value;
    if (meta == null) return const SizedBox.shrink();

    String? clean(String? v) => (v != null && v.trim().isNotEmpty) ? v : null;
    final date = meta.uploadDate;
    final rows = <Widget>[
      if (clean(meta.uploader) != null)
        _InfoRow(
          icon: Icons.person_outline,
          value: meta.uploader!,
          onTap: () =>
              _openHub(context, 'uploader', meta.uploader!, meta.uploader!),
        ),
      if (clean(meta.uploaderId) != null)
        _InfoRow(icon: Icons.alternate_email, value: meta.uploaderId!),
      if (clean(meta.playlistTitle) != null)
        _InfoRow(
          icon: Icons.playlist_play,
          value: meta.playlistTitle!,
          onTap: clean(meta.playlistId) == null
              ? null
              : () => _openHub(
                  context,
                  'playlist',
                  meta.playlistId!,
                  meta.playlistTitle!,
                ),
        ),
      if (date != null)
        _InfoRow(icon: Icons.event_outlined, value: 'Uploaded ${_ymd(date)}'),
    ];
    final description = clean(meta.description);
    if (rows.isEmpty && description == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rows,
          if (description != null) ...[
            SizedBox(height: tokens.spaceMd),
            Text('Description', style: theme.textTheme.titleSmall),
            SizedBox(height: tokens.spaceXs),
            _ExpandableText(text: description),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.value, this.onTap});
  final IconData icon;
  final String value;

  /// When set, the row becomes a tappable link (used to open an entity hub).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    final tappable = onTap != null;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: tappable ? tokens.accent : scheme.onSurfaceVariant,
        ),
        SizedBox(width: tokens.spaceSm),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tappable ? tokens.accent : null,
            ),
          ),
        ),
        if (tappable) Icon(Icons.chevron_right, size: 18, color: tokens.accent),
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spaceXs),
      child: tappable
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              child: row,
            )
          : row,
    );
  }
}

/// A description that collapses to a few lines with a Show more/less toggle.
class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});
  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  static const _collapsedLines = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: _collapsedLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : _collapsedLines,
              overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
            ),
            if (overflows)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Show less' : 'Show more'),
              ),
          ],
        );
      },
    );
  }
}

class _TagsRow extends ConsumerWidget {
  const _TagsRow({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final tags = ref.watch(tagsForItemProvider(itemId));
    return tags.maybeWhen(
      data: (list) => list.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.only(top: tokens.spaceLg),
              child: Wrap(
                spacing: tokens.spaceSm,
                runSpacing: tokens.spaceXs,
                children: [
                  for (final t in list)
                    ActionChip(
                      label: Text(t.name),
                      onPressed: () => _openHub(context, 'tag', t.name, t.name),
                    ),
                ],
              ),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// The collections this item belongs to, as tappable chips (P9i).
class _CollectionsRow extends ConsumerWidget {
  const _CollectionsRow({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final collections = ref.watch(collectionsForItemProvider(itemId));
    return collections.maybeWhen(
      data: (list) => list.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.only(top: tokens.spaceLg),
              child: Wrap(
                spacing: tokens.spaceSm,
                runSpacing: tokens.spaceXs,
                children: [
                  for (final c in list)
                    ActionChip(
                      avatar: const Icon(Icons.collections_bookmark, size: 18),
                      label: Text(c.name),
                      onPressed: () =>
                          context.push('/collection/${c.id}', extra: c.name),
                    ),
                ],
              ),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ExportButton extends ConsumerStatefulWidget {
  const _ExportButton({required this.item});
  final MediaItem item;

  @override
  ConsumerState<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends ConsumerState<_ExportButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);

    if (widget.item.storageState == 'exported') {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(tokens.spaceMd),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(tokens.radiusMd),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: scheme.onSecondaryContainer),
            SizedBox(width: tokens.spaceSm),
            Text(
              'Saved to device',
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      );
    }

    final folder = ref
        .watch(settingsControllerProvider)
        .asData
        ?.value
        .exportFolder;
    final destination = folder ?? 'gallery (Movies/Music/Pictures/GrabBit)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: tokens.accent,
              foregroundColor: tokens.onAccent,
            ),
            onPressed: _busy ? null : _export,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_alt),
            label: const Text('Save to device'),
          ),
        ),
        SizedBox(height: tokens.spaceXs),
        Text(
          'Saves to $destination',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    final settings = ref.read(settingsControllerProvider).asData?.value;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(libraryRepositoryProvider)
          .export(widget.item, treeUri: settings?.exportFolder);
      ref.invalidate(mediaItemByIdProvider(widget.item.id));
      messenger.showSnackBar(const SnackBar(content: Text('Saved to device')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _BrokenMedia extends StatelessWidget {
  const _BrokenMedia();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.broken_image_outlined,
        color: scheme.onSurfaceVariant,
        size: 48,
      ),
    );
  }
}

/// Shimmering placeholder while the item row loads.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Shimmer(
      child: ListView(
        children: [
          const AspectRatio(aspectRatio: 16 / 9, child: Skeleton(radius: 0)),
          Padding(
            padding: EdgeInsets.all(tokens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(height: 26, width: 260, radius: tokens.radiusSm),
                SizedBox(height: tokens.spaceSm),
                Skeleton(height: 12, width: 160, radius: tokens.radiusSm),
                SizedBox(height: tokens.spaceLg),
                Skeleton(height: 14, radius: tokens.radiusSm),
                SizedBox(height: tokens.spaceSm),
                Skeleton(height: 14, radius: tokens.radiusSm),
                SizedBox(height: tokens.spaceSm),
                Skeleton(height: 14, width: 220, radius: tokens.radiusSm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerView extends ConsumerStatefulWidget {
  const _PlayerView({required this.itemId, required this.filePath});
  final String itemId;
  final String filePath;

  @override
  ConsumerState<_PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<_PlayerView> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  String? _error;
  bool _looping = false;
  bool _marked = false;
  File? _track; // selected subtitle sidecar; null = off
  late final List<File> _tracks = subtitleSidecars(widget.filePath);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final video = VideoPlayerController.file(File(widget.filePath));
      await video.initialize();
      if (!mounted) {
        await video.dispose();
        return;
      }
      video.addListener(_onTick);
      setState(() {
        _video = video;
        _chewie = _build(video, null);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Stamp the item "played" the first time playback actually starts.
  void _onTick() {
    if (!_marked && (_video?.value.isPlaying ?? false)) {
      _marked = true;
      ref.read(metadataRepositoryProvider).markPlayed(widget.itemId);
    }
  }

  ChewieController _build(VideoPlayerController video, Subtitles? subtitles) =>
      ChewieController(
        videoPlayerController: video,
        autoPlay: false,
        looping: _looping,
        allowedScreenSleep: false,
        aspectRatio: video.value.aspectRatio,
        playbackSpeeds: const [0.25, 0.5, 1, 1.25, 1.5, 2],
        subtitle: subtitles,
        // Surfaced in Chewie's options sheet alongside "Playback speed".
        additionalOptions: (context) => [
          OptionItem(
            onTap: (ctx) {
              Navigator.pop(ctx);
              _toggleLoop();
            },
            iconData: _looping ? Icons.repeat_on : Icons.repeat,
            title: 'Loop',
            subtitle: _looping ? 'On' : 'Off',
          ),
          if (_tracks.isNotEmpty)
            OptionItem(
              onTap: (ctx) {
                Navigator.pop(ctx);
                _pickSubtitle(ctx);
              },
              iconData: Icons.subtitles,
              title: 'Subtitles',
              subtitle: _track == null ? 'Off' : subtitleLabel(_track!.path),
            ),
        ],
      );

  void _toggleLoop() {
    final next = !_looping;
    _video?.setLooping(next);
    _looping = next;
    _rebuild();
  }

  Future<void> _pickSubtitle(BuildContext context) async {
    final chosen = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Off'),
              selected: _track == null,
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final f in _tracks)
              ListTile(
                title: Text(subtitleLabel(f.path)),
                selected: _track?.path == f.path,
                onTap: () => Navigator.pop(ctx, f.path),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return; // dismissed
    await _setSubtitle(chosen.isEmpty ? null : File(chosen));
  }

  Future<void> _setSubtitle(File? file) async {
    Subtitles? subs;
    if (file != null) {
      final content = await file.readAsString();
      final isVtt = file.path.toLowerCase().endsWith('.vtt');
      final ClosedCaptionFile parsed = isVtt
          ? WebVTTCaptionFile(content)
          : SubRipCaptionFile(content);
      subs = Subtitles([
        for (final (i, c) in parsed.captions.indexed)
          Subtitle(index: i, start: c.start, end: c.end, text: c.text),
      ]);
    }
    final video = _video;
    if (video == null || !mounted) return;
    _track = file;
    _rebuild(subtitles: subs);
  }

  /// Recreates the Chewie controller (reusing the video controller, so position
  /// and speed survive) to apply a new loop/subtitle config.
  void _rebuild({Subtitles? subtitles}) {
    final video = _video;
    if (video == null) return;
    final old = _chewie;
    setState(() => _chewie = _build(video, subtitles));
    old?.dispose(); // disposes the Chewie controller only, not the video
  }

  @override
  void dispose() {
    _video?.removeListener(_onTick);
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(child: Text('Cannot play file: $_error'));
    }
    final chewie = _chewie;
    if (chewie == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Chewie(controller: chewie);
  }
}
