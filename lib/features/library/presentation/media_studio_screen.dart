import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/engine/media_tools_engine.dart';
import 'package:grabbit/core/engine/media_tools_ops.dart';
import 'package:grabbit/core/engine/media_tools_provider.dart';
import 'package:grabbit/core/storage/media_storage.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/duration_format.dart';
import 'package:grabbit/core/utils/task_id.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/library/data/media_tools_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';

/// On-device editing tools that produce a new library item, leaving the
/// original untouched. Video: trim, frame extract, rotate/flip/mirror, reverse,
/// extract audio. Image: rotate/flip/mirror, convert.
class MediaStudioScreen extends ConsumerStatefulWidget {
  const MediaStudioScreen({required this.itemId, super.key});
  final String itemId;

  @override
  ConsumerState<MediaStudioScreen> createState() => _MediaStudioScreenState();
}

class _MediaStudioScreenState extends ConsumerState<MediaStudioScreen> {
  StreamSubscription<ToolProgress>? _sub;
  String? _jobId;
  double? _progress;
  bool _running = false;
  String _label = '';

  RangeValues? _trim; // seconds
  double? _framePos; // seconds

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _run(
    MediaItem source, {
    required String label,
    required String outExt,
    required List<String> Function(String input, String output) build,
    int? outDurationSec,
  }) async {
    if (_running) return;
    final messenger = ScaffoldMessenger.of(context);
    final jobId = newTaskId();
    final mediaDir = await ref.read(mediaStorageProvider).mediaDirectory();
    Directory('${mediaDir.path}/$jobId').createSync(recursive: true);
    final output = '${mediaDir.path}/$jobId/$label.$outExt';
    final job = MediaJob(
      id: jobId,
      args: build(source.filePath, output),
      outputPath: output,
      totalDurationMs: source.durationSec == null
          ? null
          : source.durationSec! * 1000,
    );
    setState(() {
      _jobId = jobId;
      _progress = null;
      _running = true;
      _label = label;
    });
    _sub = ref.read(mediaToolsEngineProvider).run(job).listen((p) async {
      switch (p.stage) {
        case ToolStage.running:
          setState(() => _progress = p.percent);
        case ToolStage.done:
          final size = await File(output).length();
          await ref
              .read(mediaToolsRepositoryProvider)
              .saveEdited(
                id: jobId,
                source: source,
                title: '${source.title} ($label)',
                outputPath: output,
                durationSec: outDurationSec,
                sizeBytes: size,
              );
          if (!mounted) return;
          setState(() => _running = false);
          messenger.showSnackBar(
            SnackBar(
              content: Text('Saved "$label" as a new item'),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () => context.push('/item/$jobId'),
              ),
            ),
          );
        case ToolStage.error:
          if (!mounted) return;
          setState(() => _running = false);
          messenger.showSnackBar(
            SnackBar(content: Text(p.error ?? 'Editing failed')),
          );
      }
    });
  }

  Future<void> _cancel() async {
    final id = _jobId;
    if (id != null) await ref.read(mediaToolsEngineProvider).cancel(id);
  }

  String _ext(MediaItem row) => row.filePath.split('.').last;

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(mediaItemByIdProvider(widget.itemId));
    return Scaffold(
      appBar: AppBar(title: const Text('Studio')),
      body: item.when(
        loading: () => const _StudioSkeleton(),
        error: (e, _) => ErrorView(
          message: 'Failed to load item: $e',
          onRetry: () => ref.invalidate(mediaItemByIdProvider(widget.itemId)),
        ),
        data: (row) {
          if (row == null) {
            return const EmptyState(
              icon: Icons.broken_image_outlined,
              title: 'Item not found',
              message: 'This item may have been removed.',
            );
          }
          return Stack(
            children: [
              _toolsFor(row),
              if (_running)
                _RunningOverlay(
                  progress: _progress,
                  label: _label,
                  onCancel: _cancel,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _toolsFor(MediaItem row) {
    if (row.type == 'image') return _imageTools(row);
    if (row.type == 'video') return _videoTools(row);
    return const EmptyState(
      icon: Icons.edit_off_outlined,
      title: 'Editing not available',
      message: 'Tools are available for video and image items.',
    );
  }

  Widget _videoTools(MediaItem row) {
    final ext = _ext(row);
    final tokens = GrabBitTokens.of(context);
    return ListView(
      padding: EdgeInsets.all(tokens.spaceLg),
      children: [
        _Preview(item: row),
        SizedBox(height: tokens.spaceLg),
        if (row.durationSec != null) ...[
          _ToolCard(
            title: 'Trim',
            child: _TrimCard(
              durationSec: row.durationSec!,
              values: _trim ??= RangeValues(0, row.durationSec!.toDouble()),
              onChanged: _running ? null : (v) => setState(() => _trim = v),
              onApply: () => _run(
                row,
                label: 'trim',
                outExt: ext,
                outDurationSec: (_trim!.end - _trim!.start).round(),
                build: (i, o) => trimArgs(
                  input: i,
                  output: o,
                  start: Duration(milliseconds: (_trim!.start * 1000).round()),
                  duration: Duration(
                    milliseconds: ((_trim!.end - _trim!.start) * 1000).round(),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: tokens.spaceLg),
          _ToolCard(
            title: 'Extract frame',
            child: _FrameCard(
              durationSec: row.durationSec!,
              value: _framePos ??= 0,
              onChanged: _running ? null : (v) => setState(() => _framePos = v),
              onApply: () => _run(
                row,
                label: 'frame',
                outExt: 'jpg',
                build: (i, o) => frameArgs(
                  input: i,
                  output: o,
                  at: Duration(milliseconds: (_framePos! * 1000).round()),
                ),
              ),
            ),
          ),
          SizedBox(height: tokens.spaceLg),
        ],
        _ToolCard(
          title: 'Transform',
          child: _chipWrap([
            _opChip(
              'Rotate left',
              Icons.rotate_left,
              () => _run(
                row,
                label: 'rotated',
                outExt: ext,
                build: (i, o) =>
                    rotateArgs(input: i, output: o, clockwise: false),
              ),
            ),
            _opChip(
              'Rotate right',
              Icons.rotate_right,
              () => _run(
                row,
                label: 'rotated',
                outExt: ext,
                build: (i, o) =>
                    rotateArgs(input: i, output: o, clockwise: true),
              ),
            ),
            _opChip(
              'Mirror',
              Icons.flip,
              () => _run(
                row,
                label: 'mirrored',
                outExt: ext,
                build: (i, o) => flipArgs(input: i, output: o, vertical: false),
              ),
            ),
            _opChip(
              'Flip',
              Icons.flip_camera_android,
              () => _run(
                row,
                label: 'flipped',
                outExt: ext,
                build: (i, o) => flipArgs(input: i, output: o, vertical: true),
              ),
            ),
            _opChip(
              'Reverse',
              Icons.fast_rewind,
              () => _run(
                row,
                label: 'reversed',
                outExt: ext,
                outDurationSec: row.durationSec,
                build: (i, o) => reverseArgs(input: i, output: o),
              ),
            ),
          ]),
        ),
        SizedBox(height: tokens.spaceLg),
        _ToolCard(
          title: 'Convert',
          child: _chipWrap([
            _opChip(
              'Extract audio (M4A)',
              Icons.music_note,
              () => _run(
                row,
                label: 'audio',
                outExt: 'm4a',
                build: (i, o) => extractAudioArgs(input: i, output: o),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _imageTools(MediaItem row) {
    final ext = _ext(row);
    final tokens = GrabBitTokens.of(context);
    return ListView(
      padding: EdgeInsets.all(tokens.spaceLg),
      children: [
        _Preview(item: row),
        SizedBox(height: tokens.spaceLg),
        _ToolCard(
          title: 'Transform',
          child: _chipWrap([
            _opChip(
              'Rotate left',
              Icons.rotate_left,
              () => _run(
                row,
                label: 'rotated',
                outExt: ext,
                build: (i, o) =>
                    rotateArgs(input: i, output: o, clockwise: false),
              ),
            ),
            _opChip(
              'Rotate right',
              Icons.rotate_right,
              () => _run(
                row,
                label: 'rotated',
                outExt: ext,
                build: (i, o) =>
                    rotateArgs(input: i, output: o, clockwise: true),
              ),
            ),
            _opChip(
              'Mirror',
              Icons.flip,
              () => _run(
                row,
                label: 'mirrored',
                outExt: ext,
                build: (i, o) => flipArgs(input: i, output: o, vertical: false),
              ),
            ),
            _opChip(
              'Flip',
              Icons.flip_camera_android,
              () => _run(
                row,
                label: 'flipped',
                outExt: ext,
                build: (i, o) => flipArgs(input: i, output: o, vertical: true),
              ),
            ),
          ]),
        ),
        SizedBox(height: tokens.spaceLg),
        _ToolCard(
          title: 'Convert',
          child: _chipWrap([
            for (final fmt in const ['jpg', 'png', 'webp'])
              if (fmt != ext.toLowerCase())
                _opChip(
                  'To ${fmt.toUpperCase()}',
                  Icons.transform,
                  () => _run(
                    row,
                    label: fmt,
                    outExt: fmt,
                    build: (i, o) => convertArgs(input: i, output: o),
                  ),
                ),
          ]),
        ),
      ],
    );
  }

  Widget _chipWrap(List<Widget> chips) {
    final tokens = GrabBitTokens.of(context);
    return Wrap(
      spacing: tokens.spaceSm,
      runSpacing: tokens.spaceSm,
      children: chips,
    );
  }

  Widget _opChip(String label, IconData icon, VoidCallback onTap) => ActionChip(
    avatar: Icon(icon, size: 18),
    label: Text(label),
    onPressed: _running ? null : onTap,
  );
}

/// Rounded media preview shown above the editing tools.
class _Preview extends StatelessWidget {
  const _Preview({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radiusLg),
      child: ColoredBox(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: MediaThumb(item: item),
        ),
      ),
    );
  }
}

/// A titled card grouping one set of editing controls.
class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            SizedBox(height: tokens.spaceSm),
            child,
          ],
        ),
      ),
    );
  }
}

class _TrimCard extends StatelessWidget {
  const _TrimCard({
    required this.durationSec,
    required this.values,
    required this.onChanged,
    required this.onApply,
  });
  final int durationSec;
  final RangeValues values;
  final ValueChanged<RangeValues>? onChanged;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${formatDuration(values.start.round())} – ${formatDuration(values.end.round())}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        RangeSlider(
          values: values,
          max: durationSec.toDouble(),
          labels: RangeLabels(
            formatDuration(values.start.round()),
            formatDuration(values.end.round()),
          ),
          onChanged: onChanged,
        ),
        SizedBox(height: tokens.spaceSm),
        FilledButton.icon(
          onPressed: (onChanged == null || values.end <= values.start)
              ? null
              : onApply,
          icon: const Icon(Icons.content_cut),
          label: const Text('Trim to new item'),
        ),
      ],
    );
  }
}

class _FrameCard extends StatelessWidget {
  const _FrameCard({
    required this.durationSec,
    required this.value,
    required this.onChanged,
    required this.onApply,
  });
  final int durationSec;
  final double value;
  final ValueChanged<double>? onChanged;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'at ${formatDuration(value.round())}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Slider(
          value: value,
          max: durationSec.toDouble(),
          label: formatDuration(value.round()),
          onChanged: onChanged,
        ),
        SizedBox(height: tokens.spaceSm),
        FilledButton.icon(
          onPressed: onChanged == null ? null : onApply,
          icon: const Icon(Icons.image_outlined),
          label: const Text('Save frame as image'),
        ),
      ],
    );
  }
}

class _RunningOverlay extends StatelessWidget {
  const _RunningOverlay({
    required this.progress,
    required this.label,
    required this.onCancel,
  });
  final double? progress;
  final String label;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final op = label.isEmpty
        ? 'Working…'
        : '${label[0].toUpperCase()}${label.substring(1)}…';
    return ColoredBox(
      color: theme.colorScheme.scrim.withValues(alpha: 0.6),
      child: Center(
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusXl),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spaceXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: progress == null ? null : progress! / 100,
                  ),
                ),
                SizedBox(height: tokens.spaceLg),
                Text(op, style: theme.textTheme.titleSmall),
                SizedBox(height: tokens.spaceXs),
                Text(
                  progress == null ? 'Preparing…' : '${progress!.round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: tokens.spaceSm),
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmering placeholder while the item row loads.
class _StudioSkeleton extends StatelessWidget {
  const _StudioSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Shimmer(
      child: ListView(
        padding: EdgeInsets.all(tokens.spaceLg),
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Skeleton(radius: tokens.radiusLg),
          ),
          SizedBox(height: tokens.spaceLg),
          Skeleton(height: 96, radius: tokens.radiusLg),
          SizedBox(height: tokens.spaceLg),
          Skeleton(height: 96, radius: tokens.radiusLg),
        ],
      ),
    );
  }
}
