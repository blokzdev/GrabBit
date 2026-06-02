import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/ai/generation_provider.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/async_fade.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/ai_summary.dart';
import 'package:grabbit/features/library/presentation/graph_entity_providers.dart';
import 'package:grabbit/features/library/presentation/item_ai_tags_provider.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

class MetadataEditScreen extends ConsumerStatefulWidget {
  const MetadataEditScreen({required this.itemId, super.key});
  final String itemId;

  @override
  ConsumerState<MetadataEditScreen> createState() => _MetadataEditScreenState();
}

class _MetadataEditScreenState extends ConsumerState<MetadataEditScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagController = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final item = ref.watch(mediaItemByIdProvider(widget.itemId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ContentBounds(
        child: AsyncFade(
          value: item,
          loading: () => const _FormSkeleton(),
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
            if (!_loaded) {
              _titleController.text = row.title;
              _notesController.text = row.notes ?? '';
              _loaded = true;
            }
            return ListView(
              padding: EdgeInsets.symmetric(vertical: tokens.spaceMd),
              children: [
                const SectionHeader('Details'),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.spaceLg),
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      SizedBox(height: tokens.spaceMd),
                      TextField(
                        controller: _notesController,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: tokens.spaceLg),
                _TagsEditor(itemId: widget.itemId, controller: _tagController),
                SizedBox(height: tokens.spaceLg),
                _CollectionsEditor(itemId: widget.itemId),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    final repo = ref.read(metadataRepositoryProvider);
    await repo.updateTitle(widget.itemId, _titleController.text);
    await repo.updateNotes(
      widget.itemId,
      _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    ref.invalidate(mediaItemByIdProvider(widget.itemId));
    if (mounted) Navigator.of(context).pop();
  }
}

class _TagsEditor extends ConsumerWidget {
  const _TagsEditor({required this.itemId, required this.controller});
  final String itemId;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final tags = ref.watch(tagsForItemProvider(itemId));
    final repo = ref.read(metadataRepositoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Tags'),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tags.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (list) => list.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: EdgeInsets.only(bottom: tokens.spaceSm),
                        child: Wrap(
                          spacing: tokens.spaceSm,
                          runSpacing: tokens.spaceXs,
                          children: [
                            for (final tag in list)
                              Chip(
                                label: Text(tag.name),
                                onDeleted: () =>
                                    repo.removeTagFromItem(itemId, tag.id),
                              ),
                          ],
                        ),
                      ),
              ),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Add a tag',
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add tag',
                    onPressed: () => _add(repo),
                  ),
                ),
                onSubmitted: (_) => _add(repo),
              ),
              _Suggestions(itemId: itemId, repo: repo),
              _AiTagSuggestions(itemId: itemId, repo: repo),
            ],
          ),
        ),
      ],
    );
  }

  void _add(MetadataRepository repo) {
    repo.addTagToItem(itemId, controller.text);
    controller.clear();
  }
}

/// Graph-suggested tags (co-occurring across the library), tappable to apply.
/// Renders nothing when the graph is unavailable or has no suggestion — so the
/// editor is unchanged on devices without the graph (P10c-c-2).
class _Suggestions extends ConsumerWidget {
  const _Suggestions({required this.itemId, required this.repo});
  final String itemId;
  final MetadataRepository repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final suggestions =
        ref.watch(tagSuggestionsProvider(itemId)).asData?.value ?? const [];
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggested',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: tokens.spaceXs),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceXs,
            children: [
              for (final tag in suggestions)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(tag),
                  onPressed: () => repo.addTagToItem(itemId, tag),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// On-device LLM tag suggestions (P13c) — a separate, gated "AI suggestions" row
/// below the graph suggestions. Hidden where no generation model fits the device
/// (the graph suggestions remain). A "Suggest tags with AI" button generates
/// chips that apply via the same `addTagToItem` path; tags are never auto-added.
class _AiTagSuggestions extends ConsumerWidget {
  const _AiTagSuggestions({required this.itemId, required this.repo});
  final String itemId;
  final MetadataRepository repo;

  Future<void> _onSuggest(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final engine = ref.read(generationEngineProvider);
    final enabled =
        ref.read(settingsControllerProvider).asData?.value.generationEnabled ??
        false;
    final modelReady = enabled && await engine.ensureReady();
    switch (aiSummaryAction(
      eligible: ref.read(activeGenerationModelProvider) != null,
      enabled: enabled,
      modelReady: modelReady,
    )) {
      case AiSummaryAction.unavailable:
        return;
      case AiSummaryAction.offerSetup:
      case AiSummaryAction.offerDownload:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Set up on-device text generation to suggest tags'),
            ),
          );
        await router.push('/settings/ai');
      case AiSummaryAction.summarizeNow:
        await ref.read(itemAiTagsProvider(itemId).notifier).suggest();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    // No generation model fits this device → only the graph suggestions show.
    if (ref.watch(activeGenerationModelProvider) == null) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(itemAiTagsProvider(itemId));
    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: tokens.spaceXs),
              Text(
                'AI suggestions',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (state.busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: () => _onSuggest(context, ref),
                  child: Text(
                    state.suggestions.isEmpty
                        ? 'Suggest tags with AI'
                        : 'Again',
                  ),
                ),
            ],
          ),
          if (state.suggestions.isNotEmpty) ...[
            SizedBox(height: tokens.spaceXs),
            Wrap(
              spacing: tokens.spaceSm,
              runSpacing: tokens.spaceXs,
              children: [
                for (final tag in state.suggestions)
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(tag),
                    onPressed: () {
                      repo.addTagToItem(itemId, tag);
                      ref.read(itemAiTagsProvider(itemId).notifier).remove(tag);
                    },
                  ),
              ],
            ),
          ],
          if (state.error != null)
            Padding(
              padding: EdgeInsets.only(top: tokens.spaceXs),
              child: Text(
                state.error!,
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

class _CollectionsEditor extends ConsumerWidget {
  const _CollectionsEditor({required this.itemId});
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final all = ref.watch(collectionsProvider);
    final mine = ref.watch(collectionsForItemProvider(itemId));
    final repo = ref.read(metadataRepositoryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A section header with a trailing inline-create action.
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spaceLg,
            tokens.spaceLg,
            tokens.spaceSm,
            tokens.spaceXs,
          ),
          child: Row(
            children: [
              Text(
                'Collections',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New'),
                onPressed: () => _createDialog(context, repo),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spaceLg),
          child: all.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (collections) {
              final memberIds = (mine.asData?.value ?? [])
                  .map((c) => c.id)
                  .toSet();
              if (collections.isEmpty) {
                return Text(
                  'No collections yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                children: [
                  for (final c in collections)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.name),
                      value: memberIds.contains(c.id),
                      onChanged: (checked) => (checked ?? false)
                          ? repo.addItemToCollection(itemId, c.id)
                          : repo.removeItemFromCollection(itemId, c.id),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _createDialog(
    BuildContext context,
    MetadataRepository repo,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New collection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await repo.createCollection(name);
    }
  }
}

/// Shimmering placeholder while the item row loads.
class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Shimmer(
      child: ListView(
        padding: EdgeInsets.all(tokens.spaceLg),
        children: [
          Skeleton(height: 56, radius: tokens.radiusMd),
          SizedBox(height: tokens.spaceMd),
          Skeleton(height: 96, radius: tokens.radiusMd),
          SizedBox(height: tokens.spaceLg),
          Skeleton(height: 16, width: 80, radius: tokens.radiusSm),
          SizedBox(height: tokens.spaceSm),
          Skeleton(height: 32, radius: tokens.radiusPill),
        ],
      ),
    );
  }
}
