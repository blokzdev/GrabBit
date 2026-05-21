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

/// On-device editing tools (P6a: trim + frame extract) that produce a new
/// library item, leaving the original untouched.
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
          if (row.type == 'audio' || row.durationSec == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Trim and frame tools need a video with a known duration. '
                  'More tools (rotate, flip, convert, image editing) are coming.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Stack(
            children: [
              _Tools(
                durationSec: row.durationSec!,
                trim: _trim ??= RangeValues(0, row.durationSec!.toDouble()),
                framePos: _framePos ??= 0,
                onTrimChanged: (v) => setState(() => _trim = v),
                onFrameChanged: (v) => setState(() => _framePos = v),
                running: _running,
                onTrim: () => _run(
                  row,
                  label: 'trim',
                  outExt: row.filePath.split('.').last,
                  outDurationSec: (_trim!.end - _trim!.start).round(),
                  build: (input, output) => trimArgs(
                    input: input,
                    output: output,
                    start: Duration(
                      milliseconds: (_trim!.start * 1000).round(),
                    ),
                    duration: Duration(
                      milliseconds: ((_trim!.end - _trim!.start) * 1000)
                          .round(),
                    ),
                  ),
                ),
                onFrame: () => _run(
                  row,
                  label: 'frame',
                  outExt: 'jpg',
                  build: (input, output) => frameArgs(
                    input: input,
                    output: output,
                    at: Duration(milliseconds: (_framePos! * 1000).round()),
                  ),
                ),
              ),
              if (_running)
                _RunningOverlay(progress: _progress, onCancel: _cancel),
            ],
          );
        },
      ),
    );
  }
}

class _Tools extends StatelessWidget {
  const _Tools({
    required this.durationSec,
    required this.trim,
    required this.framePos,
    required this.onTrimChanged,
    required this.onFrameChanged,
    required this.running,
    required this.onTrim,
    required this.onFrame,
  });

  final int durationSec;
  final RangeValues trim;
  final double framePos;
  final ValueChanged<RangeValues> onTrimChanged;
  final ValueChanged<double> onFrameChanged;
  final bool running;
  final VoidCallback onTrim;
  final VoidCallback onFrame;

  String _fmt(double s) {
    final d = Duration(seconds: s.round());
    final m = d.inMinutes.toString().padLeft(2, '0');
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = durationSec.toDouble();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Trim', style: theme.textTheme.titleMedium),
        Text(
          '${_fmt(trim.start)} – ${_fmt(trim.end)}',
          style: theme.textTheme.bodySmall,
        ),
        RangeSlider(
          values: trim,
          max: max,
          labels: RangeLabels(_fmt(trim.start), _fmt(trim.end)),
          onChanged: running ? null : onTrimChanged,
        ),
        FilledButton.icon(
          onPressed: running || trim.end <= trim.start ? null : onTrim,
          icon: const Icon(Icons.content_cut),
          label: const Text('Trim to new item'),
        ),
        const Divider(height: 32),
        Text('Extract frame', style: theme.textTheme.titleMedium),
        Text('at ${_fmt(framePos)}', style: theme.textTheme.bodySmall),
        Slider(
          value: framePos,
          max: max,
          label: _fmt(framePos),
          onChanged: running ? null : onFrameChanged,
        ),
        FilledButton.icon(
          onPressed: running ? null : onFrame,
          icon: const Icon(Icons.image_outlined),
          label: const Text('Save frame as image'),
        ),
      ],
    );
  }
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
