import 'package:grabbit/core/ai/generation_provider.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/tag_suggestions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'item_ai_tags_provider.g.dart';

/// Screen-scoped state for on-device LLM tag suggestions for one item (P13c).
/// Ephemeral — nothing is cached; the provider auto-disposes when the editor
/// closes.
class ItemAiTagsState {
  const ItemAiTagsState({
    this.suggestions = const [],
    this.busy = false,
    this.error,
  });

  /// Suggested tag names not yet applied.
  final List<String> suggestions;
  final bool busy;
  final String? error;

  ItemAiTagsState copyWith({
    List<String>? suggestions,
    bool? busy,
    String? error,
  }) => ItemAiTagsState(
    suggestions: suggestions ?? this.suggestions,
    busy: busy ?? this.busy,
    error: error,
  );
}

/// Per-item AI tag-suggestion controller (P13c). The metadata editor's AI row
/// calls [suggest]; tapping a chip applies the tag (via `addTagToItem`) and
/// [remove]s it from the local list.
@riverpod
class ItemAiTags extends _$ItemAiTags {
  @override
  ItemAiTagsState build(String itemId) => const ItemAiTagsState();

  /// Generates tag suggestions from the item's title + description/transcript/
  /// OCR text, excluding tags already applied. Assumes a generation model is
  /// ready (the caller gates on that).
  Future<void> suggest() async {
    final repo = ref.read(metadataRepositoryProvider);
    final item = await repo.mediaItemById(itemId);
    final meta = await repo.metadataForItem(itemId);
    final source = [
      if (item != null) item.title,
      ?meta?.description,
      ?meta?.transcript,
      ?meta?.ocrText,
    ].where((s) => s.trim().isNotEmpty).join('\n');
    if (source.trim().isEmpty) {
      state = const ItemAiTagsState(error: 'Nothing to tag');
      return;
    }
    final engine = ref.read(generationEngineProvider);
    state = state.copyWith(busy: true, error: null);
    try {
      final existing = await repo.tagNamesForItem(itemId);
      final p = buildTagPrompt(source);
      final buffer = StringBuffer();
      await for (final token in engine.generate(
        p.prompt,
        systemPrompt: p.systemPrompt,
      )) {
        buffer.write(token);
      }
      final tags = parseTagSuggestions(
        buffer.toString(),
        exclude: existing.toSet(),
      );
      state = ItemAiTagsState(
        suggestions: tags,
        error: tags.isEmpty ? 'No tags suggested' : null,
      );
    } on InferenceException catch (e) {
      state = ItemAiTagsState(error: "Couldn't suggest tags — ${e.message}");
    }
  }

  /// Drops [tag] from the suggestion list (after it's applied).
  void remove(String tag) => state = state.copyWith(
    suggestions: [
      for (final t in state.suggestions)
        if (t != tag) t,
    ],
  );
}
