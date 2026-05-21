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
import 'package:grabbit/core/utils/task_id.dart';
import 'package:grabbit/features/library/data/media_tools_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';

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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load item: $e')),
        data: (row) {
          if (row == null) return const Center(child: Text('Item not found'));
          return Stack(
            children: [
              _toolsFor(row),
              if (_running)
                _RunningOverlay(progress: _progress, onCancel: _cancel),
            ],
          );
        },
      ),
    );
  }

  Widget _toolsFor(MediaItem row) {
    if (row.type == 'image') return _imageTools(row);
    if (row.type == 'video') return _videoTools(row);
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Editing tools are available for video and image items.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _videoTools(MediaItem row) {
    final ext = _ext(row);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (row.durationSec != null) ...[
          _TrimCard(
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
          const Divider(height: 32),
          _FrameCard(
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
          const Divider(height: 32),
        ],
        Text('Transform', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
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
          ],
        ),
        const Divider(height: 32),
        Text('Convert', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
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
          ],
        ),
      ],
    );
  }

  Widget _imageTools(MediaItem row) {
    final ext = _ext(row);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Transform', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
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
          ],
        ),
        const Divider(height: 32),
        Text('Convert', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
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
          ],
        ),
      ],
    );
  }

  Widget _opChip(String label, IconData icon, VoidCallback onTap) => ActionChip(
    avatar: Icon(icon, size: 18),
    label: Text(label),
    onPressed: _running ? null : onTap,
  );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trim', style: theme.textTheme.titleMedium),
        Text(
          '${_fmt(values.start)} – ${_fmt(values.end)}',
          style: theme.textTheme.bodySmall,
        ),
        RangeSlider(
          values: values,
          max: durationSec.toDouble(),
          labels: RangeLabels(_fmt(values.start), _fmt(values.end)),
          onChanged: onChanged,
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Extract frame', style: theme.textTheme.titleMedium),
        Text('at ${_fmt(value)}', style: theme.textTheme.bodySmall),
        Slider(
          value: value,
          max: durationSec.toDouble(),
          label: _fmt(value),
          onChanged: onChanged,
        ),
        FilledButton.icon(
          onPressed: onChanged == null ? null : onApply,
          icon: const Icon(Icons.image_outlined),
          label: const Text('Save frame as image'),
        ),
      ],
    );
  }
}

String _fmt(double s) {
  final d = Duration(seconds: s.round());
  final m = d.inMinutes.toString().padLeft(2, '0');
  final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$sec';
}

class _RunningOverlay extends StatelessWidget {
  const _RunningOverlay({required this.progress, required this.onCancel});
  final double? progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                const SizedBox(height: 16),
                Text(progress == null ? 'Working…' : '${progress!.round()}%'),
                const SizedBox(height: 8),
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
