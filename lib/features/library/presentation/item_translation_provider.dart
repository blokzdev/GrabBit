import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/translation_provider.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'item_translation_provider.g.dart';

/// Screen-scoped translation state for one item (P13b-2). Holds the translated
/// description/transcript plus the chosen target + detected source, and an
/// original/translated toggle. Ephemeral — nothing is cached to the DB; the
/// provider auto-disposes when item detail closes.
class ItemTranslationState {
  const ItemTranslationState({
    this.targetLang,
    this.sourceLang,
    this.description,
    this.transcript,
    this.showingOriginal = false,
    this.busy = false,
    this.error,
  });

  /// BCP-47 code translated into, or null when no translation is active.
  final String? targetLang;

  /// BCP-47 code detected as the source, or null.
  final String? sourceLang;

  /// Translated description / transcript (null when not translated).
  final String? description;
  final String? transcript;

  /// When true, sections show the original text despite an active translation.
  final bool showingOriginal;
  final bool busy;
  final String? error;

  /// Whether a translation is active and currently being shown.
  bool get hasTranslation => targetLang != null && !showingOriginal;

  ItemTranslationState copyWith({
    String? targetLang,
    String? sourceLang,
    String? description,
    String? transcript,
    bool? showingOriginal,
    bool? busy,
    String? error,
  }) => ItemTranslationState(
    targetLang: targetLang ?? this.targetLang,
    sourceLang: sourceLang ?? this.sourceLang,
    description: description ?? this.description,
    transcript: transcript ?? this.transcript,
    showingOriginal: showingOriginal ?? this.showingOriginal,
    busy: busy ?? this.busy,
    error: error,
  );
}

/// Per-item translation controller (P13b-2). The item-detail handler resolves
/// the target/source + ensures models, then calls [translate]; the description
/// and transcript sections watch this to render translated text with a
/// "Show original" toggle.
@riverpod
class ItemTranslation extends _$ItemTranslation {
  @override
  ItemTranslationState build(String itemId) => const ItemTranslationState();

  /// Translates the item's description + transcript from [source] to [target]
  /// (BCP-47). Assumes the required models are present (the caller downloads
  /// them first). Per-field failures surface as [ItemTranslationState.error].
  Future<void> translate({
    required String source,
    required String target,
  }) async {
    final meta = await ref
        .read(metadataRepositoryProvider)
        .metadataForItem(itemId);
    final description = meta?.description;
    final transcript = meta?.transcript;
    final engine = ref.read(translationEngineProvider);
    state = state.copyWith(busy: true, showingOriginal: false);
    try {
      final translatedDescription =
          (description != null && description.trim().isNotEmpty)
          ? await engine.translate(description, source: source, target: target)
          : null;
      final translatedTranscript =
          (transcript != null && transcript.trim().isNotEmpty)
          ? await engine.translate(transcript, source: source, target: target)
          : null;
      state = ItemTranslationState(
        targetLang: target,
        sourceLang: source,
        description: translatedDescription,
        transcript: translatedTranscript,
      );
    } on InferenceException catch (e) {
      state = ItemTranslationState(error: e.message);
    }
  }

  /// Flips between the translated text and the original (when a translation is
  /// active).
  void toggleOriginal() {
    if (state.targetLang == null) return;
    state = state.copyWith(showingOriginal: !state.showingOriginal);
  }

  /// Clears any active translation.
  void clear() => state = const ItemTranslationState();
}
