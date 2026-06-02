import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/ai/generation_provider.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/ocr_provider.dart';
import 'package:grabbit/core/ai/translation_provider.dart';
import 'package:grabbit/core/ai/transcription_engine.dart';
import 'package:grabbit/core/ai/transcription_model.dart';
import 'package:grabbit/core/ai/transcription_provider.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:grabbit/core/graph/graph_store_provider.dart';
import 'package:grabbit/core/text/textrank.dart';
import 'package:grabbit/core/text/transcript_dedup.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/byte_format.dart';
import 'package:grabbit/core/utils/duration_format.dart';
import 'package:grabbit/core/utils/subtitle_files.dart';
import 'package:grabbit/core/widgets/async_fade.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/core/share/external_share_service.dart';
import 'package:grabbit/features/downloader/data/download_request_builder.dart';
import 'package:grabbit/features/library/data/library_repository.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/data/transcript_service.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/media_actions.dart';
import 'package:grabbit/features/library/presentation/ai_summary.dart';
import 'package:grabbit/features/library/presentation/item_translation_provider.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';
import 'package:grabbit/features/library/presentation/transcribe_fallback.dart';
import 'package:grabbit/features/library/presentation/translation.dart';
import 'package:grabbit/features/library/presentation/related_provider.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:video_player/video_player.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(mediaItemByIdProvider(itemId));
    final row = item.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(row?.title ?? 'Item'),
        actions: [
          if (row != null) ...[
            IconButton(
              icon: AnimatedSwitcher(
                duration: GrabBitTokens.of(context).motionShort,
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  row.isFavorite ? Icons.star : Icons.star_outline,
                  key: ValueKey(row.isFavorite),
                ),
              ),
              tooltip: row.isFavorite ? 'Unfavorite' : 'Favorite',
              onPressed: () async {
                await ref
                    .read(metadataRepositoryProvider)
                    .toggleFavorite(itemId, !row.isFavorite);
                ref.invalidate(mediaItemByIdProvider(itemId));
              },
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) async {
                switch (value) {
                  case 'save':
                    await saveItems(context, ref, [row]);
                  case 'move':
                    await moveItemsTo(context, ref, [row]);
                  case 'studio':
                    await context.push('/item/$itemId/studio');
                  case 'graph':
                    await context.push('/item/$itemId/graph');
                  case 'edit':
                    await context.push('/item/$itemId/edit');
                  case 'transcript':
                    await _getTranscript(context, ref, row);
                  case 'translate':
                    await _translateItem(context, ref, row);
                  case 'share':
                    await shareItems(ref, [row]);
                  case 'copy':
                    await copyUrl(context, [row]);
                  case 'open':
                    await ref
                        .read(externalShareServiceProvider)
                        .openUrl(row.sourceUrl);
                  case 'delete':
                    await _deleteAndPop(context, ref, row);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'save',
                  child: Text('Save to device'),
                ),
                const PopupMenuItem(
                  value: 'move',
                  child: Text('Move to folder'),
                ),
                const PopupMenuItem(
                  value: 'studio',
                  child: Text('Edit in Studio'),
                ),
                if (ref.watch(graphStoreProvider).isAvailable)
                  const PopupMenuItem(
                    value: 'graph',
                    child: Text('View in graph'),
                  ),
                const PopupMenuItem(value: 'edit', child: Text('Edit info')),
                const PopupMenuItem(
                  value: 'transcript',
                  child: Text('Get transcript'),
                ),
                if (ref.watch(translationEngineProvider).isAvailable)
                  const PopupMenuItem(
                    value: 'translate',
                    child: Text('Translate…'),
                  ),
                const PopupMenuItem(value: 'share', child: Text('Share file')),
                const PopupMenuItem(
                  value: 'copy',
                  child: Text('Copy source URL'),
                ),
                const PopupMenuItem(
                  value: 'open',
                  child: Text('Open source link'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ],
      ),
      body: ContentBounds(
        child: AsyncFade(
          value: item,
          loading: () => const _DetailSkeleton(),
          error: (e, _) => ErrorView(
            message: 'Failed to load item: $e',
            onRetry: () => ref.invalidate(mediaItemByIdProvider(itemId)),
          ),
          data: (row) => row == null
              ? const EmptyState(
                  icon: Icons.broken_image_outlined,
                  title: 'Item not found',
                  message: 'This item may have been removed.',
                )
              : _ItemBody(item: row),
        ),
      ),
    );
  }
}

/// Confirms, deletes the item (honoring the secure-delete setting), then pops
/// the detail screen — keeping the detail-screen delete distinct from the
/// grid menu's `deleteItems` (which stays on the list).
Future<void> _deleteAndPop(
  BuildContext context,
  WidgetRef ref,
  MediaItem row,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  final ok = await confirm(
    context,
    title: 'Delete this item?',
    message:
        'Permanently removes the downloaded file from GrabBit. This cannot be '
        'undone.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!ok) return;
  final secure =
      ref.read(settingsControllerProvider).asData?.value.secureDelete ?? false;
  await ref.read(libraryRepositoryProvider).deleteItem(row, secure: secure);
  if (router.canPop()) router.pop();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Deleted')));
}

class _ItemBody extends StatefulWidget {
  const _ItemBody({required this.item});
  final MediaItem item;

  @override
  State<_ItemBody> createState() => _ItemBodyState();
}

class _ItemBodyState extends State<_ItemBody> {
  /// The active player controller (P10f-4), shared with the synced transcript
  /// so it can seek and follow playback. Null for image items / before init.
  final _player = ValueNotifier<VideoPlayerController?>(null);

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    return ListView(
      children: [
        Hero(
          tag: mediaHeroTag(item.id),
          // The destination hosts the heavy player/zoomable image; fly the
          // lightweight thumbnail instead so the transition stays smooth.
          flightShuttleBuilder: (_, _, _, _, _) => MediaThumb(item: item),
          child: ColoredBox(
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: item.type == 'image'
                  ? InteractiveViewer(
                      child: Image.file(
                        File(item.filePath),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const _BrokenMedia(),
                      ),
                    )
                  : _PlayerView(
                      itemId: item.id,
                      filePath: item.filePath,
                      player: _player,
                    ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(tokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: theme.textTheme.headlineSmall),
              SizedBox(height: tokens.spaceXs),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InkWell(
                    onTap: () =>
                        _openHub(context, 'site', item.site, item.site),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    child: Text(
                      item.site,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '  ·  Saved ${_ymd(item.createdAt.toLocal())}'
                    '${item.lastAccessedAt != null ? '  ·  Last played ${_ymd(item.lastAccessedAt!.toLocal())}' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              _DetailChips(item: item),
              _AiSummarySection(itemId: item.id),
              _SummarySection(itemId: item.id),
              if (item.type == 'image') _OcrSection(item: item),
              _MetadataSection(itemId: item.id),
              _TranscriptSection(
                itemId: item.id,
                mediaPath: item.filePath,
                player: _player,
              ),
              if (item.notes != null && item.notes!.isNotEmpty) ...[
                SizedBox(height: tokens.spaceMd),
                Text(item.notes!, style: theme.textTheme.bodyMedium),
              ],
              _TagsRow(itemId: item.id),
              _CollectionsRow(itemId: item.id),
              SizedBox(height: tokens.spaceLg),
              _ExportButton(item: item),
              _RelatedSection(itemId: item.id),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens the entity hub listing every item for [type]/[value] (uploader, site,
/// playlist, or tag). [value] is the filter key; [name] the display label.
void _openHub(BuildContext context, String type, String value, String name) =>
    context.push(
      Uri(path: '/hub/$type', queryParameters: {'v': value}).toString(),
      extra: name,
    );

/// "More like this" — a horizontal carousel of related items (graph + vector).
/// Renders nothing until results arrive (or when the graph is unavailable), so
/// it never adds empty chrome to the detail screen.
class _RelatedSection extends ConsumerWidget {
  const _RelatedSection({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final related =
        ref.watch(relatedItemsProvider(itemId)).asData?.value ?? const [];
    if (related.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('More like this', style: theme.textTheme.titleMedium),
          SizedBox(height: tokens.spaceSm),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: related.length,
              separatorBuilder: (_, _) => SizedBox(width: tokens.spaceMd),
              itemBuilder: (_, i) => _RelatedCard(item: related[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final radius = BorderRadius.circular(tokens.radiusMd);
    return SizedBox(
      width: 150,
      child: InkWell(
        onTap: () => context.push('/item/${item.id}'),
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: radius,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MediaThumb(item: item),
                    if (item.type == 'video')
                      Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.scrim.withValues(
                              alpha: 0.4,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: tokens.spaceXs),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Quick technical facts (type / duration / resolution / size) as tonal chips.
class _DetailChips extends StatelessWidget {
  const _DetailChips({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final resolution = (item.width != null && item.height != null)
        ? '${item.width}×${item.height}'
        : '';
    final chips = [
      item.type.toUpperCase(),
      formatDuration(item.durationSec),
      resolution,
      formatBytes(item.sizeBytes),
    ].where((e) => e.isNotEmpty).toList();
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceMd),
      child: Wrap(
        spacing: tokens.spaceSm,
        runSpacing: tokens.spaceXs,
        children: [for (final c in chips) _chip(context, c)],
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceMd,
        vertical: tokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Uploader / username / playlist / upload date + an expandable description,
/// from the metadata captured at download time.
/// Extractive TextRank summary (P10e) for an item's text. Memoized per item;
/// recomputes whenever the item's metadata changes. Prefers the captured
/// transcript (P10f) and falls back to the description; because it watches the
/// metadata, the summary recomputes the instant a transcript is written.
final itemSummaryProvider = Provider.family<List<String>, String>((
  ref,
  itemId,
) {
  final meta = ref.watch(metadataForItemProvider(itemId)).asData?.value;
  final text = meta?.transcript ?? meta?.description;
  if (text == null || text.trim().isEmpty) return const [];
  return summarize(text);
});

/// A short extractive TL;DR shown above the full metadata/description. Hidden
/// when there's nothing worth condensing (short or absent text).
class _SummarySection extends ConsumerWidget {
  const _SummarySection({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final sentences = ref.watch(itemSummaryProvider(itemId));
    if (sentences.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Summary', style: theme.textTheme.titleSmall),
          SizedBox(height: tokens.spaceXs),
          for (final s in sentences)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.spaceXs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: theme.textTheme.bodyMedium),
                  Expanded(child: Text(s, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// On-device abstractive (LLM) summary (P13a) — the first real generation
/// feature, layered **above** the extractive TextRank floor. User-initiated and
/// cached (`MediaMetadata.aiSummary`); streamed live while generating. Gated on
/// the generation tier: ineligible devices never see it and keep the extractive
/// summary. When the device can generate but the user hasn't enabled it, the
/// action routes to AI settings (the on-ramp idiom from `transcribe_fallback`).
class _AiSummarySection extends ConsumerStatefulWidget {
  const _AiSummarySection({required this.itemId});
  final String itemId;

  @override
  ConsumerState<_AiSummarySection> createState() => _AiSummarySectionState();
}

class _AiSummarySectionState extends ConsumerState<_AiSummarySection> {
  bool _busy = false;
  String? _streaming; // live partial text while generating
  String? _error;

  String? _sourceText() {
    final meta = ref.read(metadataForItemProvider(widget.itemId)).asData?.value;
    final text = meta?.transcript ?? meta?.description;
    return (text == null || text.trim().isEmpty) ? null : text;
  }

  Future<void> _onAction() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final engine = ref.read(generationEngineProvider);
    final enabled =
        ref.read(settingsControllerProvider).value?.generationEnabled ?? false;
    // Only probe the model when enabled — never load a model the user hasn't
    // opted into. `ensureReady` does not download.
    final modelReady = enabled && await engine.ensureReady();
    final action = aiSummaryAction(
      eligible: ref.read(activeGenerationModelProvider) != null,
      enabled: enabled,
      modelReady: modelReady,
    );
    switch (action) {
      case AiSummaryAction.unavailable:
        return;
      case AiSummaryAction.offerSetup:
      case AiSummaryAction.offerDownload:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Set up on-device text generation to summarize'),
            ),
          );
        await router.push('/settings/ai');
      case AiSummaryAction.summarizeNow:
        await _summarize();
    }
  }

  Future<void> _summarize() async {
    final text = _sourceText();
    if (text == null) return;
    final engine = ref.read(generationEngineProvider);
    final model = ref.read(activeGenerationModelProvider);
    final repo = ref.read(metadataRepositoryProvider);
    setState(() {
      _busy = true;
      _streaming = '';
      _error = null;
    });
    try {
      final p = buildSummaryPrompt(text);
      final buffer = StringBuffer();
      await for (final token in engine.generate(
        p.prompt,
        systemPrompt: p.systemPrompt,
      )) {
        buffer.write(token);
        if (mounted) setState(() => _streaming = buffer.toString());
      }
      final summary = buffer.toString().trim();
      if (summary.isNotEmpty) {
        await repo.updateAiSummary(widget.itemId, summary, modelId: model?.id);
      }
    } on InferenceException catch (e) {
      if (mounted) setState(() => _error = "Couldn't summarize — ${e.message}");
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _streaming = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    // No generation model fits this device → render nothing; the extractive
    // summary below remains the floor.
    if (ref.watch(activeGenerationModelProvider) == null) {
      return const SizedBox.shrink();
    }
    if (_sourceText() == null) return const SizedBox.shrink();

    final meta = ref
        .watch(metadataForItemProvider(widget.itemId))
        .asData
        ?.value;
    final cached = meta?.aiSummary;
    final body = _busy ? (_streaming ?? '') : (cached ?? '');
    final hasBody = body.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: tokens.spaceXs),
              Text('AI summary', style: theme.textTheme.titleSmall),
              const Spacer(),
              if (_busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: _onAction,
                  child: Text(hasBody ? 'Regenerate' : 'Summarize with AI'),
                ),
            ],
          ),
          if (hasBody) ...[
            SizedBox(height: tokens.spaceXs),
            Text(body, style: theme.textTheme.bodyMedium),
            if (!_busy)
              Text(
                'Generated on-device',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ] else if (!_busy)
            Text(
              'Condense this item into a couple of sentences, on-device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(top: tokens.spaceXs),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// On-device OCR (P13b-1) for image items: a "Scan text" action that extracts
/// text from the image with ML Kit (bundled Latin model, fully offline), caches
/// it (`MediaMetadata.ocrText`), shows it, and feeds full-text search. Hidden
/// when the engine can't run on this host (non-Android).
class _OcrSection extends ConsumerStatefulWidget {
  const _OcrSection({required this.item});
  final MediaItem item;

  @override
  ConsumerState<_OcrSection> createState() => _OcrSectionState();
}

class _OcrSectionState extends ConsumerState<_OcrSection> {
  bool _busy = false;
  String? _error;
  bool _noText = false; // the last scan found nothing readable

  Future<void> _scan() async {
    final engine = ref.read(ocrEngineProvider);
    final repo = ref.read(metadataRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
      _noText = false;
    });
    try {
      final text = (await engine.recognizeText(widget.item.filePath)).trim();
      if (text.isEmpty) {
        if (mounted) setState(() => _noText = true);
      } else {
        await repo.updateOcrText(widget.item.id, text);
      }
    } on InferenceException catch (e) {
      if (mounted) setState(() => _error = "Couldn't scan text — ${e.message}");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    // Engine can't run here (non-Android) → nothing to offer.
    if (!ref.watch(ocrEngineProvider).isAvailable) {
      return const SizedBox.shrink();
    }
    final meta = ref
        .watch(metadataForItemProvider(widget.item.id))
        .asData
        ?.value;
    final cached = meta?.ocrText;
    final hasText = cached != null && cached.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.document_scanner_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: tokens.spaceXs),
              Text('Text in image', style: theme.textTheme.titleSmall),
              const Spacer(),
              if (_busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: _scan,
                  child: Text(hasText ? 'Rescan' : 'Scan text'),
                ),
            ],
          ),
          if (hasText) ...[
            SizedBox(height: tokens.spaceXs),
            Text(cached, style: theme.textTheme.bodyMedium),
            Text(
              'Recognized on-device',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else if (!_busy)
            Text(
              _noText
                  ? 'No readable text found in this image.'
                  : 'Find and search text inside this image, on-device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(top: tokens.spaceXs),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Curated caption languages offered by the on-demand fetch (P10f-2). The
/// in-app language is always shown (prepended if missing) and pre-selected.
const List<({String code, String name})> _captionLanguages = [
  (code: 'en', name: 'English'),
  (code: 'es', name: 'Spanish'),
  (code: 'fr', name: 'French'),
  (code: 'de', name: 'German'),
  (code: 'pt', name: 'Portuguese'),
  (code: 'it', name: 'Italian'),
  (code: 'ru', name: 'Russian'),
  (code: 'hi', name: 'Hindi'),
  (code: 'ar', name: 'Arabic'),
  (code: 'ja', name: 'Japanese'),
  (code: 'ko', name: 'Korean'),
  (code: 'zh', name: 'Chinese'),
];

String _captionLanguageLabel(String code) {
  for (final l in _captionLanguages) {
    if (l.code == code) return l.name;
  }
  return code;
}

/// "Get transcript" action (P10f). Uses captions already on disk when present
/// (instant, offline); otherwise fetches them online in a chosen language
/// (P10f-2) and stores the result, so the summary + transcript view update.
Future<void> _getTranscript(
  BuildContext context,
  WidgetRef ref,
  MediaItem row,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final transcripts = ref.read(transcriptServiceProvider);
  final metadata = ref.read(metadataRepositoryProvider);

  // Local-first: build from any caption files already beside the media.
  final local = await transcripts.extractTimed(row.filePath);
  if (local != null) {
    await metadata.updateTranscript(
      row.id,
      local.flat,
      cuesJson: local.cuesJson,
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Transcript built from captions')),
    );
    return;
  }

  // None on disk → fetch online in a language the user picks.
  if (!context.mounted) return;
  final settings = await ref.read(settingsControllerProvider.future);
  final defaultLang = settings.captionLanguage;
  if (!context.mounted) return;
  final lang = await _pickCaptionLanguage(context, defaultLang);
  if (lang == null) return; // dismissed

  messenger.showSnackBar(const SnackBar(content: Text('Fetching captions…')));
  final req = buildCaptionFetchRequest(
    sourceUrl: row.sourceUrl,
    mediaPath: row.filePath,
    settings: settings,
    lang: lang,
  );
  try {
    final terminal = await ref
        .read(downloadEngineProvider)
        .download(req)
        .firstWhere(
          (p) =>
              p.stage == DownloadStage.done ||
              p.stage == DownloadStage.error ||
              p.stage == DownloadStage.canceled,
        );
    if (terminal.stage != DownloadStage.done) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't fetch captions")),
      );
      return;
    }
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text("Couldn't fetch captions — check your connection"),
      ),
    );
    return;
  }

  final fetched = await transcripts.extractTimed(
    row.filePath,
    preferLang: lang,
  );
  if (fetched == null) {
    // No captions anywhere → offer the on-device whisper fallback (P12e-3).
    if (!context.mounted) return;
    await _whisperFallback(context, ref, row, lang);
    return;
  }
  await metadata.updateTranscript(
    row.id,
    fetched.flat,
    cuesJson: fetched.cuesJson,
  );
  messenger.showSnackBar(const SnackBar(content: Text('Transcript ready')));
}

/// The on-device transcription fallback (P12e-3) for the manual "Get transcript"
/// action, reached only when an item has **no captions** (local or online). A
/// self-contained 3-state on-ramp: set transcription up (download + enable),
/// just download the model, or transcribe straight away — see
/// [transcribeFallbackAction]. The model download is one-time and reusable.
Future<void> _whisperFallback(
  BuildContext context,
  WidgetRef ref,
  MediaItem row,
  String lang,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final enabled = ref
      .read(settingsControllerProvider)
      .asData
      ?.value
      .transcriptionEnabled;
  final engine = ref.read(transcriptionEngineProvider);
  final model = ref.read(activeTranscriptionModelProvider);
  final modelReady = await engine.ensureReady();
  if (!context.mounted) return;

  final action = transcribeFallbackAction(
    // Matches the factory gate: a real whisper engine exists only on Android.
    supported: Platform.isAndroid,
    enabled: enabled ?? false,
    modelReady: modelReady,
  );

  switch (action) {
    case TranscribeFallbackAction.unavailable:
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No captions available in ${_captionLanguageLabel(lang)}',
          ),
        ),
      );
      return;
    case TranscribeFallbackAction.offerSetup:
      final ok = await confirm(
        context,
        title: 'Transcribe without captions?',
        message:
            'On-device transcription is off. Set it up to transcribe this '
            'video with ${model.displayName} (~${model.approxDownloadMb} MB, '
            'one-time download). Everything stays on your device.',
        confirmLabel: 'Set up',
      );
      if (!ok || !context.mounted) return;
      await ref
          .read(settingsControllerProvider.notifier)
          .setTranscriptionEnabled(true);
      if (!await _downloadWhisperModel(messenger, engine, model)) return;
    case TranscribeFallbackAction.offerDownload:
      final ok = await confirm(
        context,
        title: 'Download transcription model?',
        message:
            'Download ${model.displayName} (~${model.approxDownloadMb} MB) to '
            'transcribe this video on-device? One-time, reusable.',
        confirmLabel: 'Download',
      );
      if (!ok || !context.mounted) return;
      if (!await _downloadWhisperModel(messenger, engine, model)) return;
    case TranscribeFallbackAction.transcribeNow:
      break;
  }

  if (!context.mounted) return;
  messenger.showSnackBar(
    const SnackBar(content: Text('Transcribing on-device…')),
  );
  try {
    final result = await engine.transcribe(row.filePath);
    if (result.flat.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No speech detected')),
      );
      return;
    }
    await ref
        .read(metadataRepositoryProvider)
        .updateTranscript(row.id, result.flat, cuesJson: result.cuesJson);
    messenger.showSnackBar(const SnackBar(content: Text('Transcript ready')));
  } on InferenceException catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not transcribe — ${e.message}')),
    );
  }
}

/// Downloads the whisper [model] with a progress snackbar; returns whether it
/// succeeded (a storage/other failure shows a friendly message and returns false).
Future<bool> _downloadWhisperModel(
  ScaffoldMessengerState messenger,
  TranscriptionEngine engine,
  TranscriptionModel model,
) async {
  messenger.showSnackBar(
    SnackBar(content: Text('Downloading ${model.displayName}…')),
  );
  try {
    await engine.downloadModel();
    return true;
  } on InferenceException catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e.code == InferenceErrorCode.downloadFailed
              ? e.message
              : "Couldn't download ${model.displayName} — ${e.message}",
        ),
      ),
    );
    return false;
  }
}

/// On-device translation (P13b-2). Picks a target language (default = the app
/// language), detects the source, downloads the ~30 MB pack(s) on first use,
/// then translates the description + transcript via `itemTranslationProvider`.
/// All on-device; nothing leaves the phone.
Future<void> _translateItem(
  BuildContext context,
  WidgetRef ref,
  MediaItem row,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final engine = ref.read(translationEngineProvider);
  final meta = ref.read(metadataForItemProvider(row.id)).asData?.value;
  final desc = meta?.description;
  final tr = meta?.transcript;
  final text = (desc != null && desc.trim().isNotEmpty)
      ? desc
      : (tr != null && tr.trim().isNotEmpty ? tr : null);
  if (text == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Nothing to translate')),
    );
    return;
  }
  final defaultLang =
      ref.read(settingsControllerProvider).asData?.value.captionLanguage ??
      'en';
  final target = await _pickCaptionLanguage(
    context,
    defaultLang,
    title: 'Translate to…',
  );
  if (target == null) return;

  final source = await engine.identifyLanguage(text);
  final downloaded =
      await engine.isModelDownloaded(source) &&
      await engine.isModelDownloaded(target);
  final readiness = translateReadiness(
    engineAvailable: engine.isAvailable,
    source: source,
    target: target,
    modelsDownloaded: downloaded,
  );

  if (readiness == TranslateReadiness.unavailable) {
    messenger.showSnackBar(
      const SnackBar(content: Text("Translation isn't available here")),
    );
    return;
  }
  if (readiness == TranslateReadiness.notDetected) {
    messenger.showSnackBar(
      const SnackBar(content: Text("Couldn't detect the language")),
    );
    return;
  }
  if (readiness == TranslateReadiness.alreadyInTarget) {
    messenger.showSnackBar(
      SnackBar(content: Text('Already in ${_captionLanguageLabel(target)}')),
    );
    return;
  }
  if (readiness == TranslateReadiness.needsDownload) {
    if (!context.mounted) return;
    final ok = await confirm(
      context,
      title: 'Download language pack?',
      message:
          'Translating needs a one-time download (~30 MB per language) over '
          'Wi-Fi. It then works offline.',
      confirmLabel: 'Download',
    );
    if (!ok) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Downloading language pack…')),
      );
    try {
      await engine.downloadModel(source);
      await engine.downloadModel(target);
    } on InferenceException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text("Couldn't download — ${e.message}")),
        );
      return;
    }
  }

  // Ready (or just-downloaded): translate.
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Translating…')));
  await ref
      .read(itemTranslationProvider(row.id).notifier)
      .translate(source: source, target: target);
  final err = ref.read(itemTranslationProvider(row.id)).error;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(err ?? 'Translated to ${_captionLanguageLabel(target)}'),
      ),
    );
}

/// Bottom-sheet language picker for the on-demand caption fetch. Returns the
/// chosen language code, or null if dismissed.
Future<String?> _pickCaptionLanguage(
  BuildContext context,
  String defaultLang, {
  String title = 'Fetch captions in…',
}) {
  final langs = [..._captionLanguages];
  if (!langs.any((l) => l.code == defaultLang)) {
    langs.insert(0, (code: defaultLang, name: defaultLang.toUpperCase()));
  }
  return showModalBottomSheet<String?>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(dense: true, enabled: false, title: Text(title)),
          for (final l in langs)
            ListTile(
              title: Text(l.name),
              selected: l.code == defaultLang,
              onTap: () => Navigator.pop(ctx, l.code),
            ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Other…'),
            onTap: () async {
              final code = await _promptLanguageCode(ctx);
              if (ctx.mounted) Navigator.pop(ctx, code);
            },
          ),
        ],
      ),
    ),
  );
}

/// Prompts for an arbitrary language code (power users). Null = cancelled.
Future<String?> _promptLanguageCode(BuildContext context) async {
  final controller = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Language code'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. nl, pt-BR'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Fetch'),
        ),
      ],
    ),
  );
  return (code == null || code.isEmpty) ? null : code;
}

/// The stored transcript (P10f). Shows a synced, tappable, timestamped view
/// (P10f-4) when timed cues + a live player are available, else a flat
/// expandable block. Builds a transcript once from caption sidecars when
/// "backfill on open" is enabled (no transcript yet) and lazily fills in timed
/// cues for transcripts captured before P10f-4.
class _TranscriptSection extends ConsumerStatefulWidget {
  const _TranscriptSection({
    required this.itemId,
    required this.mediaPath,
    required this.player,
  });
  final String itemId;
  final String mediaPath;
  final ValueNotifier<VideoPlayerController?> player;

  @override
  ConsumerState<_TranscriptSection> createState() => _TranscriptSectionState();
}

class _TranscriptSectionState extends ConsumerState<_TranscriptSection> {
  bool _buildAttempted = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final meta = ref
        .watch(metadataForItemProvider(widget.itemId))
        .asData
        ?.value;
    final backfillOn =
        ref
            .watch(settingsControllerProvider)
            .asData
            ?.value
            .transcriptBackfill ??
        false;
    final transcript = meta?.transcript;

    if (transcript == null || transcript.trim().isEmpty) {
      if (backfillOn && !_buildAttempted) {
        _buildAttempted = true;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _buildFromSidecar(),
        );
      }
      return const SizedBox.shrink();
    }

    // Have flat text but no timed cues (e.g. captured before P10f-4): derive
    // them once from the sidecar so the synced view can light up.
    if (meta?.transcriptCues == null && !_buildAttempted) {
      _buildAttempted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _buildFromSidecar());
    }

    final cues = meta?.transcriptCues == null
        ? const <TranscriptCue>[]
        : decodeCues(meta!.transcriptCues!);

    final tr = ref.watch(itemTranslationProvider(widget.itemId));
    final showTranslated = tr.hasTranslation && tr.transcript != null;

    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transcript', style: theme.textTheme.titleSmall),
          SizedBox(height: tokens.spaceXs),
          // A translation replaces the synced view with a flat translated block
          // (the timed cues stay tied to the original text).
          if (showTranslated)
            _ExpandableText(text: tr.transcript!)
          else
            ValueListenableBuilder<VideoPlayerController?>(
              valueListenable: widget.player,
              builder: (context, controller, _) =>
                  (controller != null && cues.isNotEmpty)
                  ? _SyncedTranscript(cues: cues, controller: controller)
                  : _ExpandableText(text: transcript),
            ),
          if (tr.targetLang != null && tr.transcript != null)
            _TranslationToggle(itemId: widget.itemId),
        ],
      ),
    );
  }

  /// Builds the transcript (flat + timed cues) from caption sidecars on disk.
  Future<void> _buildFromSidecar() async {
    final timed = await ref
        .read(transcriptServiceProvider)
        .extractTimed(widget.mediaPath);
    if (timed == null || !mounted) return;
    await ref
        .read(metadataRepositoryProvider)
        .updateTranscript(widget.itemId, timed.flat, cuesJson: timed.cuesJson);
  }
}

/// A compact toggle for a translated section (P13b-2): flips between the
/// translated text and the original. Hidden until a translation is active.
class _TranslationToggle extends ConsumerWidget {
  const _TranslationToggle({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(itemTranslationProvider(itemId));
    if (tr.targetLang == null) return const SizedBox.shrink();
    final src = _captionLanguageLabel(tr.sourceLang ?? '');
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () =>
            ref.read(itemTranslationProvider(itemId).notifier).toggleOriginal(),
        child: Text(
          tr.showingOriginal
              ? 'Show translation'
              : 'Translated from $src · Show original',
        ),
      ),
    );
  }
}

/// A YouTube-style synced transcript (P10f-4): timestamped lines; tap a line to
/// seek the player; the currently-playing line highlights and auto-scrolls.
class _SyncedTranscript extends StatefulWidget {
  const _SyncedTranscript({required this.cues, required this.controller});
  final List<TranscriptCue> cues;
  final VideoPlayerController controller;

  @override
  State<_SyncedTranscript> createState() => _SyncedTranscriptState();
}

class _SyncedTranscriptState extends State<_SyncedTranscript> {
  static const double _collapsedHeight = 280;
  bool _expanded = false;
  int _activeIndex = -1;
  final _itemKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    final idx = _indexFor(widget.controller.value.position);
    if (idx == _activeIndex || !mounted) return;
    setState(() => _activeIndex = idx);
    final ctx = _itemKeys[idx]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  /// The last cue that has started at or before [pos] (binary search).
  int _indexFor(Duration pos) {
    final cues = widget.cues;
    var lo = 0, hi = cues.length - 1, ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (cues[mid].start <= pos) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final scheme = theme.colorScheme;

    final list = ListView.builder(
      shrinkWrap: true,
      physics: _expanded ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.zero,
      itemCount: widget.cues.length,
      itemBuilder: (context, i) {
        final cue = widget.cues[i];
        final active = i == _activeIndex;
        final key = _itemKeys.putIfAbsent(i, GlobalKey.new);
        return InkWell(
          key: key,
          onTap: () => widget.controller.seekTo(cue.start),
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spaceXs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    formatDuration(cue.start.inSeconds),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.accent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                SizedBox(width: tokens.spaceSm),
                Expanded(
                  child: Text(
                    cue.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: active
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_expanded)
          list
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _collapsedHeight),
            child: list,
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Show less' : 'Show full transcript'),
          ),
        ),
      ],
    );
  }
}

class _MetadataSection extends ConsumerWidget {
  const _MetadataSection({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final meta = ref.watch(metadataForItemProvider(itemId)).asData?.value;
    if (meta == null) return const SizedBox.shrink();
    final tr = ref.watch(itemTranslationProvider(itemId));

    String? clean(String? v) => (v != null && v.trim().isNotEmpty) ? v : null;
    final date = meta.uploadDate;
    final rows = <Widget>[
      if (clean(meta.uploader) != null)
        _InfoRow(
          icon: Icons.person_outline,
          value: meta.uploader!,
          onTap: () =>
              _openHub(context, 'uploader', meta.uploader!, meta.uploader!),
        ),
      if (clean(meta.uploaderId) != null)
        _InfoRow(icon: Icons.alternate_email, value: meta.uploaderId!),
      if (clean(meta.playlistTitle) != null)
        _InfoRow(
          icon: Icons.playlist_play,
          value: meta.playlistTitle!,
          onTap: clean(meta.playlistId) == null
              ? null
              : () => _openHub(
                  context,
                  'playlist',
                  meta.playlistId!,
                  meta.playlistTitle!,
                ),
        ),
      if (date != null)
        _InfoRow(icon: Icons.event_outlined, value: 'Uploaded ${_ymd(date)}'),
    ];
    final description = clean(meta.description);
    if (rows.isEmpty && description == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...rows,
          if (description != null) ...[
            SizedBox(height: tokens.spaceMd),
            Text('Description', style: theme.textTheme.titleSmall),
            SizedBox(height: tokens.spaceXs),
            _ExpandableText(
              text: (tr.hasTranslation && tr.description != null)
                  ? tr.description!
                  : description,
            ),
            if (tr.targetLang != null && tr.description != null)
              _TranslationToggle(itemId: itemId),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.value, this.onTap});
  final IconData icon;
  final String value;

  /// When set, the row becomes a tappable link (used to open an entity hub).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    final tappable = onTap != null;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: tappable ? tokens.accent : scheme.onSurfaceVariant,
        ),
        SizedBox(width: tokens.spaceSm),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tappable ? tokens.accent : null,
            ),
          ),
        ),
        if (tappable) Icon(Icons.chevron_right, size: 18, color: tokens.accent),
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spaceXs),
      child: tappable
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              child: row,
            )
          : row,
    );
  }
}

/// A description that collapses to a few lines with a Show more/less toggle.
class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});
  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  static const _collapsedLines = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: _collapsedLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : _collapsedLines,
              overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
            ),
            if (overflows)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Show less' : 'Show more'),
              ),
          ],
        );
      },
    );
  }
}

class _TagsRow extends ConsumerWidget {
  const _TagsRow({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final tags = ref.watch(tagsForItemProvider(itemId));
    return tags.maybeWhen(
      data: (list) => list.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.only(top: tokens.spaceLg),
              child: Wrap(
                spacing: tokens.spaceSm,
                runSpacing: tokens.spaceXs,
                children: [
                  for (final t in list)
                    ActionChip(
                      label: Text(t.name),
                      onPressed: () => _openHub(context, 'tag', t.name, t.name),
                    ),
                ],
              ),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// The collections this item belongs to, as tappable chips (P9i).
class _CollectionsRow extends ConsumerWidget {
  const _CollectionsRow({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final collections = ref.watch(collectionsForItemProvider(itemId));
    return collections.maybeWhen(
      data: (list) => list.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.only(top: tokens.spaceLg),
              child: Wrap(
                spacing: tokens.spaceSm,
                runSpacing: tokens.spaceXs,
                children: [
                  for (final c in list)
                    ActionChip(
                      avatar: const Icon(Icons.collections_bookmark, size: 18),
                      label: Text(c.name),
                      onPressed: () =>
                          context.push('/collection/${c.id}', extra: c.name),
                    ),
                ],
              ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);

    if (widget.item.storageState == 'exported') {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(tokens.spaceMd),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(tokens.radiusMd),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: scheme.onSecondaryContainer),
            SizedBox(width: tokens.spaceSm),
            Text(
              'Saved to device',
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
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
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: tokens.accent,
              foregroundColor: tokens.onAccent,
            ),
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
        ),
        SizedBox(height: tokens.spaceXs),
        Text(
          'Saves to $destination',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
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

class _BrokenMedia extends StatelessWidget {
  const _BrokenMedia();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.broken_image_outlined,
        color: scheme.onSurfaceVariant,
        size: 48,
      ),
    );
  }
}

/// Shimmering placeholder while the item row loads.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Shimmer(
      child: ListView(
        children: [
          const AspectRatio(aspectRatio: 16 / 9, child: Skeleton(radius: 0)),
          Padding(
            padding: EdgeInsets.all(tokens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(height: 26, width: 260, radius: tokens.radiusSm),
                SizedBox(height: tokens.spaceSm),
                Skeleton(height: 12, width: 160, radius: tokens.radiusSm),
                SizedBox(height: tokens.spaceLg),
                Skeleton(height: 14, radius: tokens.radiusSm),
                SizedBox(height: tokens.spaceSm),
                Skeleton(height: 14, radius: tokens.radiusSm),
                SizedBox(height: tokens.spaceSm),
                Skeleton(height: 14, width: 220, radius: tokens.radiusSm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerView extends ConsumerStatefulWidget {
  const _PlayerView({
    required this.itemId,
    required this.filePath,
    required this.player,
  });
  final String itemId;
  final String filePath;
  final ValueNotifier<VideoPlayerController?> player;

  @override
  ConsumerState<_PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<_PlayerView> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  String? _error;
  bool _looping = false;
  bool _marked = false;
  File? _track; // selected subtitle sidecar; null = off
  late final List<File> _tracks = subtitleSidecars(widget.filePath);

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
      video.addListener(_onTick);
      // Publish the controller so the synced transcript (P10f-4) can seek it
      // and follow its position.
      widget.player.value = video;
      setState(() {
        _video = video;
        _chewie = _build(video, null);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// Stamp the item "played" the first time playback actually starts.
  void _onTick() {
    if (!_marked && (_video?.value.isPlaying ?? false)) {
      _marked = true;
      ref.read(metadataRepositoryProvider).markPlayed(widget.itemId);
    }
  }

  ChewieController _build(VideoPlayerController video, Subtitles? subtitles) =>
      ChewieController(
        videoPlayerController: video,
        autoPlay: false,
        looping: _looping,
        allowedScreenSleep: false,
        aspectRatio: video.value.aspectRatio,
        playbackSpeeds: const [0.25, 0.5, 1, 1.25, 1.5, 2],
        subtitle: subtitles,
        // Surfaced in Chewie's options sheet alongside "Playback speed".
        additionalOptions: (context) => [
          OptionItem(
            onTap: (ctx) {
              Navigator.pop(ctx);
              _toggleLoop();
            },
            iconData: _looping ? Icons.repeat_on : Icons.repeat,
            title: 'Loop',
            subtitle: _looping ? 'On' : 'Off',
          ),
          if (_tracks.isNotEmpty)
            OptionItem(
              onTap: (ctx) {
                Navigator.pop(ctx);
                _pickSubtitle(ctx);
              },
              iconData: Icons.subtitles,
              title: 'Subtitles',
              subtitle: _track == null ? 'Off' : subtitleLabel(_track!.path),
            ),
        ],
      );

  void _toggleLoop() {
    final next = !_looping;
    _video?.setLooping(next);
    _looping = next;
    _rebuild();
  }

  Future<void> _pickSubtitle(BuildContext context) async {
    final chosen = await showModalBottomSheet<String?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Off'),
              selected: _track == null,
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final f in _tracks)
              ListTile(
                title: Text(subtitleLabel(f.path)),
                selected: _track?.path == f.path,
                onTap: () => Navigator.pop(ctx, f.path),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return; // dismissed
    await _setSubtitle(chosen.isEmpty ? null : File(chosen));
  }

  Future<void> _setSubtitle(File? file) async {
    Subtitles? subs;
    if (file != null) {
      final content = await file.readAsString();
      final isVtt = file.path.toLowerCase().endsWith('.vtt');
      final ClosedCaptionFile parsed = isVtt
          ? WebVTTCaptionFile(content)
          : SubRipCaptionFile(content);
      subs = Subtitles([
        for (final (i, c) in parsed.captions.indexed)
          Subtitle(index: i, start: c.start, end: c.end, text: c.text),
      ]);
    }
    final video = _video;
    if (video == null || !mounted) return;
    _track = file;
    _rebuild(subtitles: subs);
  }

  /// Recreates the Chewie controller (reusing the video controller, so position
  /// and speed survive) to apply a new loop/subtitle config.
  void _rebuild({Subtitles? subtitles}) {
    final video = _video;
    if (video == null) return;
    final old = _chewie;
    setState(() => _chewie = _build(video, subtitles));
    old?.dispose(); // disposes the Chewie controller only, not the video
  }

  @override
  void dispose() {
    // Stop the transcript from holding a controller we're about to dispose.
    widget.player.value = null;
    _video?.removeListener(_onTick);
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
