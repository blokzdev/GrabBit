import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/byte_format.dart';
import 'package:grabbit/core/utils/duration_format.dart';
import 'package:grabbit/core/utils/subtitle_files.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/library/data/folder_repository.dart';
import 'package:grabbit/features/library/data/library_repository.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/folder_picker.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';
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
          if (row != null)
            IconButton(
              icon: Icon(row.isFavorite ? Icons.star : Icons.star_outline),
              tooltip: row.isFavorite ? 'Unfavorite' : 'Favorite',
              onPressed: () async {
                await ref
                    .read(metadataRepositoryProvider)
                    .toggleFavorite(itemId, !row.isFavorite);
                ref.invalidate(mediaItemByIdProvider(itemId));
              },
            ),
          IconButton(
            icon: const Icon(Icons.drive_file_move_outlined),
            tooltip: 'Move to folder',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final choice = await pickFolder(context, ref);
              if (choice == null) return;
              await ref.read(folderRepositoryProvider).moveItems([
                itemId,
              ], choice.id);
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Moved')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high_outlined),
            tooltip: 'Studio (edit)',
            onPressed: () => context.push('/item/$itemId/studio'),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit info',
            onPressed: () => context.push('/item/$itemId/edit'),
          ),
          if (row != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final router = GoRouter.of(context);
                final ok = await confirm(
                  context,
                  title: 'Delete this item?',
                  message:
                      'Permanently removes the downloaded file from GrabBit. '
                      'This cannot be undone.',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (!ok) return;
                final secure =
                    ref
                        .read(settingsControllerProvider)
                        .asData
                        ?.value
                        .secureDelete ??
                    false;
                await ref
                    .read(libraryRepositoryProvider)
                    .deleteItem(row, secure: secure);
                if (router.canPop()) router.pop();
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('Deleted')));
              },
            ),
        ],
      ),
      body: ContentBounds(
        child: item.when(
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
              Text(
                '${item.site}  ·  Saved ${_ymd(item.createdAt.toLocal())}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              _DetailChips(item: item),
              _MetadataSection(itemId: item.id),
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                SizedBox(height: tokens.spaceMd),
                Text(item.notes!, style: theme.textTheme.bodyMedium),
              ],
              _TagsRow(itemId: item.id),
              SizedBox(height: tokens.spaceLg),
              _ExportButton(item: item),
            ],
          ),
        ),
      ],
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
        _InfoRow(icon: Icons.person_outline, value: meta.uploader!),
      if (clean(meta.uploaderId) != null)
        _InfoRow(icon: Icons.alternate_email, value: meta.uploaderId!),
      if (clean(meta.playlistTitle) != null)
        _InfoRow(icon: Icons.playlist_play, value: meta.playlistTitle!),
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
  const _InfoRow({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spaceXs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          SizedBox(width: tokens.spaceSm),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
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
                children: [for (final t in list) Chip(label: Text(t.name))],
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
