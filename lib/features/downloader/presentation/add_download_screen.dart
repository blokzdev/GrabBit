import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/features/downloader/presentation/downloader_controller.dart';

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
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Paste a link',
                hintText: 'https://…',
                border: OutlineInputBorder(),
              ),
              onSubmitted: controller.probe,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: state.phase == DownloaderPhase.probing
                  ? null
                  : () => controller.probe(_urlController.text),
              icon: const Icon(Icons.search),
              label: const Text('Check link'),
            ),
            const SizedBox(height: 16),
            if (state.errorMessage != null)
              _ErrorBanner(message: state.errorMessage!),
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
                onSelected: controller.startDownload,
              ),
            if (state.phase == DownloaderPhase.downloading &&
                state.progress != null)
              _ProgressView(
                progress: state.progress!,
                onCancel: controller.cancel,
              ),
            if (state.phase == DownloaderPhase.done)
              _DoneView(
                onDone: () {
                  controller.reset();
                  _urlController.clear();
                  Navigator.of(context).maybePop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

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
      child: Row(
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

class _PresetPicker extends StatelessWidget {
  const _PresetPicker({required this.presets, required this.onSelected});
  final List<QualityPreset> presets;
  final void Function(QualityPreset) onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Download', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final preset in presets)
              ActionChip(
                avatar: Icon(
                  preset.audioOnly ? Icons.music_note : Icons.movie_outlined,
                  size: 18,
                ),
                label: Text(preset.label),
                onPressed: () => onSelected(preset),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.progress, required this.onCancel});
  final DownloadProgress progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.percent.clamp(0, 100)) / 100;
    final eta = progress.etaSec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(value: percent == 0 ? null : percent),
        const SizedBox(height: 8),
        Text(
          progress.stage == DownloadStage.merging
              ? 'Merging…'
              : '${progress.percent.toStringAsFixed(0)}%'
                    '${eta != null ? ' · ${eta}s left' : ''}',
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.close),
          label: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 48),
        const SizedBox(height: 8),
        const Text('Saved to your library'),
        const SizedBox(height: 12),
        FilledButton(onPressed: onDone, child: const Text('Done')),
      ],
    );
  }
}
