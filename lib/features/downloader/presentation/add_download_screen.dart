import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/duration_format.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/error_banner.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/downloader/presentation/downloader_controller.dart';
import 'package:grabbit/features/downloader/presentation/error_messages.dart';
import 'package:grabbit/features/downloader/presentation/selection_controller.dart';

class AddDownloadScreen extends ConsumerStatefulWidget {
  const AddDownloadScreen({super.key});

  @override
  ConsumerState<AddDownloadScreen> createState() => _AddDownloadScreenState();
}

class _AddDownloadScreenState extends ConsumerState<AddDownloadScreen> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;
    _urlController
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _check() async {
    final text = _urlController.text;
    final urls = text
        .split(RegExp(r'\s+'))
        .where((u) => u.trim().isNotEmpty)
        .toList();
    if (urls.isEmpty) return;
    if (urls.length == 1) {
      final isMulti = await ref
          .read(downloaderControllerProvider.notifier)
          .checkSingle(urls.first);
      if (isMulti && mounted) unawaited(context.push('/select'));
    } else {
      await ref.read(selectionControllerProvider.notifier).expandUrls(text);
      if (mounted) unawaited(context.push('/select'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(downloaderControllerProvider);
    final controller = ref.read(downloaderControllerProvider.notifier);
    final tokens = GrabBitTokens.of(context);
    final probing = state.phase == DownloaderPhase.probing;

    return Scaffold(
      appBar: AppBar(title: const Text('Add download')),
      body: ContentBounds(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _urlController,
                autofocus: true,
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: 'Paste one or more links',
                  hintText: 'https://…  (playlists & multiple links supported)',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste),
                    tooltip: 'Paste',
                    onPressed: _paste,
                  ),
                ),
              ),
              SizedBox(height: tokens.spaceMd),
              FilledButton.icon(
                onPressed: probing ? null : _check,
                icon: const Icon(Icons.search),
                label: const Text('Check link(s)'),
              ),
              SizedBox(height: tokens.spaceLg),
              if (state.errorMessage != null)
                Padding(
                  padding: EdgeInsets.only(bottom: tokens.spaceLg),
                  child: ErrorBanner(
                    message: friendlyError(
                      state.errorCode,
                      state.errorMessage!,
                    ),
                    actions: suggestsEngineUpdate(state.errorCode)
                        ? [
                            TextButton.icon(
                              onPressed: () => context.go('/settings'),
                              icon: const Icon(Icons.system_update_alt),
                              label: const Text('Update the downloader engine'),
                            ),
                          ]
                        : null,
                  ),
                ),
              if (probing) const _PreviewSkeleton(),
              if (state.info != null) _MediaPreview(info: state.info!),
              if (state.phase == DownloaderPhase.ready)
                _PresetPicker(
                  presets: state.availablePresets,
                  onAction: (preset, startNow) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final router = GoRouter.of(context);
                    await controller.enqueue(preset, startNow: startNow);
                    router.go('/');
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            startNow ? 'Download started' : 'Added to queue',
                          ),
                          action: SnackBarAction(
                            label: 'View queue',
                            onPressed: () => router.go('/queue'),
                          ),
                        ),
                      );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card-shaped placeholder shown while a link is being probed.
class _PreviewSkeleton extends StatelessWidget {
  const _PreviewSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Skeleton(height: 180, radius: tokens.radiusMd),
          SizedBox(height: tokens.spaceMd),
          Skeleton(height: 18, width: 240, radius: tokens.radiusSm),
          SizedBox(height: tokens.spaceSm),
          Skeleton(height: 12, width: 140, radius: tokens.radiusSm),
        ],
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.info});
  final MediaInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    final duration = formatDuration(info.durationSec);

    return Card(
      margin: EdgeInsets.only(bottom: tokens.spaceLg),
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Thumbnail(url: info.thumbnailUrl),
                    if (duration.isNotEmpty)
                      Positioned(
                        right: tokens.spaceSm,
                        bottom: tokens.spaceSm,
                        child: _DurationPill(text: duration),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: tokens.spaceMd),
            Text(info.title, style: theme.textTheme.titleMedium),
            if (info.uploader != null) ...[
              SizedBox(height: tokens.spaceXs),
              Text(
                info.uploader!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_outlined,
        color: scheme.onSurfaceVariant,
        size: 40,
      ),
    );
    final src = url;
    if (src == null) return placeholder;
    return Image.network(
      src,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

class _DurationPill extends StatelessWidget {
  const _DurationPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: tokens.spaceSm, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.scrim.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _PresetPicker extends StatefulWidget {
  const _PresetPicker({required this.presets, required this.onAction});
  final List<QualityPreset> presets;
  final void Function(QualityPreset preset, bool startNow) onAction;

  @override
  State<_PresetPicker> createState() => _PresetPickerState();
}

class _PresetPickerState extends State<_PresetPicker> {
  late QualityPreset _selected = widget.presets.first;

  @override
  void didUpdateWidget(_PresetPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.presets.contains(_selected)) _selected = widget.presets.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Quality', style: theme.textTheme.titleSmall),
        SizedBox(height: tokens.spaceSm),
        Wrap(
          spacing: tokens.spaceSm,
          children: [
            for (final preset in widget.presets)
              ChoiceChip(
                avatar: Icon(
                  preset.audioOnly ? Icons.music_note : Icons.movie_outlined,
                  size: 18,
                ),
                label: Text(preset.label),
                selected: _selected == preset,
                onSelected: (_) => setState(() => _selected = preset),
              ),
          ],
        ),
        SizedBox(height: tokens.spaceLg),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => widget.onAction(_selected, false),
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
                onPressed: () => widget.onAction(_selected, true),
                icon: const Icon(Icons.download),
                label: const Text('Download now'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
