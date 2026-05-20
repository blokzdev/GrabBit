import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/data/library_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:video_player/video_player.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(mediaItemByIdProvider(itemId));
    return Scaffold(
      appBar: AppBar(title: Text(item.asData?.value?.title ?? 'Item')),
      body: item.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load item: $e')),
        data: (row) => row == null
            ? const Center(child: Text('Item not found'))
            : _ItemBody(item: row),
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
    return ListView(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: item.type == 'image'
              ? InteractiveViewer(child: Image.file(File(item.filePath)))
              : _PlayerView(filePath: item.filePath),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Source: ${item.site}', style: theme.textTheme.bodySmall),
              Text(
                'Saved ${item.createdAt.toLocal()}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _ExportButton(item: item),
            ],
          ),
        ),
      ],
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
    if (widget.item.storageState == 'exported') {
      return Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
          const SizedBox(width: 8),
          const Text('Saved to device'),
        ],
      );
    }
    return FilledButton.icon(
      onPressed: _busy ? null : _export,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_alt),
      label: const Text('Save to device'),
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

class _PlayerView extends StatefulWidget {
  const _PlayerView({required this.filePath});
  final String filePath;

  @override
  State<_PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<_PlayerView> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  String? _error;

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
      setState(() {
        _video = video;
        _chewie = ChewieController(
          videoPlayerController: video,
          autoPlay: false,
          looping: false,
          aspectRatio: video.value.aspectRatio,
        );
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
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
