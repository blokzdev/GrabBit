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
import 'package:grabbit/core/utils/byte_format.dart';
import 'package:grabbit/features/downloader/data/download_request_builder.dart';
import 'package:grabbit/features/downloader/data/share_intake_service.dart';
import 'package:grabbit/features/downloader/presentation/downloader_controller.dart';
import 'package:grabbit/features/downloader/presentation/error_messages.dart';
import 'package:grabbit/features/downloader/presentation/selection_controller.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

class AddDownloadScreen extends ConsumerStatefulWidget {
  const AddDownloadScreen({super.key});

  @override
  ConsumerState<AddDownloadScreen> createState() => _AddDownloadScreenState();
}

class _AddDownloadScreenState extends ConsumerState<AddDownloadScreen> {
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // A link shared into the app (P8a) lands here pre-filled; consume it once
    // the first frame is up so the field and probe are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeSharedUrl());
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _consumeSharedUrl() {
    if (!mounted) return;
    final url = ref.read(pendingSharedUrlProvider.notifier).take();
    if (url == null || url.isEmpty) return;
    _urlController
      ..text = url
      ..selection = TextSelection.collapsed(offset: url.length);
    _check();
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
    // A share that arrives while this screen is already open re-fills the field.
    ref.listen(pendingSharedUrlProvider, (_, next) {
      if (next != null && next.isNotEmpty) _consumeSharedUrl();
    });
    final state = ref.watch(downloaderControllerProvider);
    final controller = ref.read(downloaderControllerProvider.notifier);
    final settings = ref.watch(settingsControllerProvider).asData?.value;
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
              if (state.phase == DownloaderPhase.ready && state.info != null)
                _FormatPicker(
                  presets: state.availablePresets,
                  formats: state.info!.formats,
                  advanced: settings?.mode == UiMode.advanced,
                  defaultAudioFormat: settings?.audioFormat ?? 'm4a',
                  defaultAudioQuality: settings?.audioQuality ?? 'best',
                  onAction:
                      ({
                        formatSelector,
                        required audioOnly,
                        audioFormat,
                        audioQuality,
                        required startNow,
                      }) async {
                        final messenger = ScaffoldMessenger.of(context);
                        final router = GoRouter.of(context);
                        await controller.enqueue(
                          formatSelector: formatSelector,
                          audioOnly: audioOnly,
                          audioFormat: audioFormat,
                          audioQuality: audioQuality,
                          startNow: startNow,
                        );
                        router.go('/');
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(
                                startNow
                                    ? 'Download started'
                                    : 'Added to queue',
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

/// Enqueue callback: a resolved yt-dlp `-f` selector + audio choices.
typedef _EnqueueAction =
    void Function({
      String? formatSelector,
      required bool audioOnly,
      String? audioFormat,
      String? audioQuality,
      required bool startNow,
    });

bool _hasVideo(MediaFormat f) => f.vcodec != null && f.vcodec != 'none';

String _formatTitle(MediaFormat f) {
  if (_hasVideo(f)) {
    return f.height != null
        ? '${f.height}p'
        : (f.label.isNotEmpty ? f.label : f.id);
  }
  return 'Audio';
}

String _formatSubtitle(MediaFormat f) {
  final codec = _hasVideo(f) ? (f.vcodec ?? '') : (f.acodec ?? '');
  final size = formatBytes(f.filesize);
  return [
    f.ext,
    codec,
    if (size.isNotEmpty) size,
  ].where((s) => s.isNotEmpty).join(' · ');
}

/// Quality/format chooser: preset chips for everyone, plus (Advanced) a list of
/// the concrete probed formats and a per-download audio codec/bitrate override.
class _FormatPicker extends StatefulWidget {
  const _FormatPicker({
    required this.presets,
    required this.formats,
    required this.advanced,
    required this.defaultAudioFormat,
    required this.defaultAudioQuality,
    required this.onAction,
  });
  final List<QualityPreset> presets;
  final List<MediaFormat> formats;
  final bool advanced;
  final String defaultAudioFormat;
  final String defaultAudioQuality;
  final _EnqueueAction onAction;

  @override
  State<_FormatPicker> createState() => _FormatPickerState();
}

class _FormatPickerState extends State<_FormatPicker> {
  late QualityPreset? _preset = widget.presets.first;
  MediaFormat? _format;
  late String _audioFormat = widget.defaultAudioFormat;
  late String _audioQuality = widget.defaultAudioQuality;

  @override
  void didUpdateWidget(_FormatPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_preset != null && !widget.presets.contains(_preset)) {
      _preset = widget.presets.first;
      _format = null;
    }
  }

  bool get _audioSelected => _format != null
      ? formatSelectorFor(_format!).audioOnly
      : (_preset?.audioOnly ?? false);

  List<MediaFormat> get _sorted {
    final list = [...widget.formats];
    list.sort((a, b) {
      final av = _hasVideo(a), bv = _hasVideo(b);
      if (av != bv) return av ? -1 : 1; // video first
      final h = (b.height ?? 0).compareTo(a.height ?? 0);
      return h != 0 ? h : (b.tbr ?? 0).compareTo(a.tbr ?? 0);
    });
    return list;
  }

  void _fire(bool startNow) {
    final sel = _format != null
        ? formatSelectorFor(_format!)
        : (selector: _preset!.formatSelector, audioOnly: _preset!.audioOnly);
    widget.onAction(
      formatSelector: sel.selector,
      audioOnly: sel.audioOnly,
      audioFormat: sel.audioOnly ? _audioFormat : null,
      audioQuality: sel.audioOnly ? _audioQuality : null,
      startNow: startNow,
    );
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
                selected: _format == null && _preset == preset,
                onSelected: (_) => setState(() {
                  _preset = preset;
                  _format = null;
                }),
              ),
          ],
        ),
        if (widget.advanced && _sorted.isNotEmpty) ...[
          SizedBox(height: tokens.spaceMd),
          _FormatList(
            formats: _sorted,
            selected: _format,
            onSelected: (f) => setState(() {
              _format = f;
              _preset = null;
            }),
          ),
        ],
        if (_audioSelected) ...[
          SizedBox(height: tokens.spaceMd),
          _AudioOptions(
            format: _audioFormat,
            quality: _audioQuality,
            onFormat: (v) => setState(() => _audioFormat = v),
            onQuality: (v) => setState(() => _audioQuality = v),
          ),
        ],
        SizedBox(height: tokens.spaceLg),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () => _fire(false),
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
                onPressed: () => _fire(true),
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

/// Expandable list of concrete probed formats (Advanced mode).
class _FormatList extends StatelessWidget {
  const _FormatList({
    required this.formats,
    required this.selected,
    required this.onSelected,
  });
  final List<MediaFormat> formats;
  final MediaFormat? selected;
  final ValueChanged<MediaFormat> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      child: ExpansionTile(
        title: Text(
          selected == null
              ? 'Choose a specific format'
              : 'Format: ${_formatTitle(selected!)}',
        ),
        initiallyExpanded: selected != null,
        children: [
          for (final f in formats)
            ListTile(
              selected: selected?.id == f.id,
              leading: Icon(
                selected?.id == f.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(_formatTitle(f)),
              subtitle: Text(_formatSubtitle(f)),
              onTap: () => onSelected(f),
            ),
        ],
      ),
    );
  }
}

/// Per-download audio codec + bitrate (overrides the global settings).
class _AudioOptions extends StatelessWidget {
  const _AudioOptions({
    required this.format,
    required this.quality,
    required this.onFormat,
    required this.onQuality,
  });
  final String format;
  final String quality;
  final ValueChanged<String> onFormat;
  final ValueChanged<String> onQuality;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Audio format'),
          trailing: DropdownButton<String>(
            value: format,
            onChanged: (v) => v == null ? null : onFormat(v),
            items: const [
              DropdownMenuItem(value: 'm4a', child: Text('M4A (AAC)')),
              DropdownMenuItem(value: 'mp3', child: Text('MP3')),
              DropdownMenuItem(value: 'opus', child: Text('Opus')),
              DropdownMenuItem(value: 'vorbis', child: Text('Vorbis')),
              DropdownMenuItem(value: 'aac', child: Text('AAC')),
              DropdownMenuItem(value: 'flac', child: Text('FLAC')),
              DropdownMenuItem(value: 'wav', child: Text('WAV')),
              DropdownMenuItem(value: 'best', child: Text('Best (source)')),
            ],
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Audio quality'),
          trailing: DropdownButton<String>(
            value: quality,
            onChanged: (v) => v == null ? null : onQuality(v),
            items: const [
              DropdownMenuItem(value: 'best', child: Text('Best')),
              DropdownMenuItem(value: '320K', child: Text('320 kbps')),
              DropdownMenuItem(value: '256K', child: Text('256 kbps')),
              DropdownMenuItem(value: '192K', child: Text('192 kbps')),
              DropdownMenuItem(value: '128K', child: Text('128 kbps')),
              DropdownMenuItem(value: '96K', child: Text('96 kbps')),
            ],
          ),
        ),
      ],
    );
  }
}
