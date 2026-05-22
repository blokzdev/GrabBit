import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/features/downloader/presentation/downloader_controller.dart';
import 'package:grabbit/features/downloader/presentation/selection_controller.dart';

/// Thumbnail picker for an expanded playlist/channel/carousel.
class SelectionScreen extends ConsumerWidget {
  const SelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(selectionControllerProvider);
    final controller = ref.read(selectionControllerProvider.notifier);
    final entries = state.allEntries;
    final selectedCount = state.selected.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Select items ($selectedCount/${state.totalCount})'),
        actions: [
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
      body: Column(
        children: [
          for (final s in state.sources.where((s) => s.error != null))
            _SourceError(url: s.url, error: s.error!),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('Nothing to download'))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: entries.length,
                    itemBuilder: (context, i) => _EntryTile(
                      entry: entries[i],
                      selected: state.selected.contains(entries[i].url),
                      onTap: () => controller.toggle(entries[i].url),
                    ),
                  ),
          ),
          _BottomBar(preset: state.preset, hasSelection: selectedCount > 0),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.selected,
    required this.onTap,
  });
  final MediaEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Icon(
                      entry.isImage
                          ? Icons.image_outlined
                          : Icons.movie_outlined,
                      color: scheme.onSurfaceVariant,
                      size: 36,
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected ? scheme.primary : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
            onPressed: () => router.push('/queue'),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(selectionControllerProvider.notifier);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Quality:'),
                const SizedBox(width: 12),
                DropdownButton<QualityPreset>(
                  value: preset,
                  onChanged: (p) => p == null ? null : controller.setPreset(p),
                  items: [
                    for (final p in QualityPreset.values)
                      DropdownMenuItem(value: p, child: Text(p.label)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasSelection
                        ? () => _finish(context, controller.addToBatch, false)
                        : null,
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Add to queue'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
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
    );
  }
}

class _SourceError extends StatelessWidget {
  const _SourceError({required this.url, required this.error});
  final String url;
  final String error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$url — $error',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }
}
