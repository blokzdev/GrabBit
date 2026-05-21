import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/data/folder_repository.dart';
import 'package:grabbit/features/library/data/library_repository.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/folder_picker.dart';
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
      appBar: AppBar(
        title: Text(item.asData?.value?.title ?? 'Item'),
        actions: [
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
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => context.push('/item/$itemId/edit'),
          ),
        ],
      ),
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
              _MetadataSection(itemId: item.id),
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(item.notes!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 12),
              _TagsRow(itemId: item.id),
              const SizedBox(height: 16),
              _ExportButton(item: item),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows the uploader / upload date / description captured at download time
/// (persisted in `media_metadata`), when any of them is present.
class _MetadataSection extends ConsumerWidget {
  const _MetadataSection({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final meta = ref.watch(metadataForItemProvider(itemId)).asData?.value;
    if (meta == null) return const SizedBox.shrink();

    final date = meta.uploadDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (meta.uploader != null && meta.uploader!.isNotEmpty)
          Text('Uploader: ${meta.uploader}', style: theme.textTheme.bodySmall),
        if (meta.uploaderId != null && meta.uploaderId!.isNotEmpty)
          Text(
            'Username: ${meta.uploaderId}',
            style: theme.textTheme.bodySmall,
          ),
        if (meta.playlistTitle != null && meta.playlistTitle!.isNotEmpty)
          Text(
            'Playlist: ${meta.playlistTitle}',
            style: theme.textTheme.bodySmall,
          ),
        if (date != null)
          Text(
            'Uploaded ${date.year}-${_pad(date.month)}-${_pad(date.day)}',
            style: theme.textTheme.bodySmall,
          ),
        if (meta.description != null &&
            meta.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Description', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(meta.description!, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

class _TagsRow extends ConsumerWidget {
  const _TagsRow({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsForItemProvider(itemId));
    return tags.maybeWhen(
      data: (list) => list.isEmpty
          ? const SizedBox.shrink()
          : Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [for (final t in list) Chip(label: Text(t.name))],
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
    if (widget.item.storageState == 'exported') {
      return Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
          const SizedBox(width: 8),
          const Text('Saved to device'),
        ],
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
        FilledButton.icon(
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
        const SizedBox(height: 4),
        Text(
          'Saves to $destination',
          style: Theme.of(context).textTheme.bodySmall,
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
