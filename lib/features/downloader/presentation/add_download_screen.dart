import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/engine/download_engine.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Add download')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              autofocus: true,
              minLines: 1,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Paste one or more links',
                hintText: 'https://…  (playlists & multiple links supported)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: state.phase == DownloaderPhase.probing ? null : _check,
              icon: const Icon(Icons.search),
              label: const Text('Check link(s)'),
            ),
            const SizedBox(height: 16),
            if (state.errorMessage != null)
              _ErrorBanner(
                message: friendlyError(state.errorCode, state.errorMessage!),
                showUpdate: suggestsEngineUpdate(state.errorCode),
              ),
            if (state.phase == DownloaderPhase.probing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
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
                          onPressed: () => router.push('/queue'),
                        ),
                      ),
                    );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.showUpdate = false});
  final String message;
  final bool showUpdate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: scheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
          if (showUpdate)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push('/settings'),
                icon: const Icon(Icons.system_update_alt),
                label: const Text('Update the downloader engine'),
              ),
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (info.thumbnailUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              info.thumbnailUrl!,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        const SizedBox(height: 12),
        Text(info.title, style: theme.textTheme.titleMedium),
        if (info.uploader != null)
          Text(info.uploader!, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Quality', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => widget.onAction(_selected, false),
                icon: const Icon(Icons.playlist_add),
                label: const Text('Add to queue'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
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
