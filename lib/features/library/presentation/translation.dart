/// Pure, engine-free helper for the on-device translation flow (P13b-2). Kept
/// out of the widget/controller so the decision is unit-testable in isolation
/// (mirrors `aiSummaryAction` / `transcribeFallbackAction`).
library;

/// What the "Translate…" action should do, given the detected source language
/// and the chosen target.
enum TranslateReadiness {
  /// On-device translation can't run here (non-Android).
  unavailable,

  /// The text's language couldn't be determined (`und`).
  notDetected,

  /// The text is already in the target language — nothing to do.
  alreadyInTarget,

  /// Translatable, but the (~30 MB) language model(s) must be downloaded first.
  needsDownload,

  /// Ready to translate now (models present).
  ready,
}

/// [source] is the detected BCP-47 code (or `'und'`); [target] the chosen code;
/// [modelsDownloaded] whether the required model(s) are already on device.
TranslateReadiness translateReadiness({
  required bool engineAvailable,
  required String source,
  required String target,
  required bool modelsDownloaded,
}) {
  if (!engineAvailable) return TranslateReadiness.unavailable;
  if (source.isEmpty || source == 'und') return TranslateReadiness.notDetected;
  if (source == target) return TranslateReadiness.alreadyInTarget;
  return modelsDownloaded
      ? TranslateReadiness.ready
      : TranslateReadiness.needsDownload;
}

/// The BCP-47 code + friendly name of every language ML Kit can translate
/// on-device (P13f-2). Used by the Translation settings card (naming downloaded
/// packs) and its "Download a language" picker. The item-detail translate flow
/// keeps its own short, curated target list (`_captionLanguages`).
const List<({String code, String name})> kTranslationLanguages = [
  (code: 'af', name: 'Afrikaans'),
  (code: 'sq', name: 'Albanian'),
  (code: 'ar', name: 'Arabic'),
  (code: 'be', name: 'Belarusian'),
  (code: 'bn', name: 'Bengali'),
  (code: 'bg', name: 'Bulgarian'),
  (code: 'ca', name: 'Catalan'),
  (code: 'zh', name: 'Chinese'),
  (code: 'hr', name: 'Croatian'),
  (code: 'cs', name: 'Czech'),
  (code: 'da', name: 'Danish'),
  (code: 'nl', name: 'Dutch'),
  (code: 'en', name: 'English'),
  (code: 'eo', name: 'Esperanto'),
  (code: 'et', name: 'Estonian'),
  (code: 'fi', name: 'Finnish'),
  (code: 'fr', name: 'French'),
  (code: 'gl', name: 'Galician'),
  (code: 'ka', name: 'Georgian'),
  (code: 'de', name: 'German'),
  (code: 'el', name: 'Greek'),
  (code: 'gu', name: 'Gujarati'),
  (code: 'ht', name: 'Haitian Creole'),
  (code: 'he', name: 'Hebrew'),
  (code: 'hi', name: 'Hindi'),
  (code: 'hu', name: 'Hungarian'),
  (code: 'is', name: 'Icelandic'),
  (code: 'id', name: 'Indonesian'),
  (code: 'ga', name: 'Irish'),
  (code: 'it', name: 'Italian'),
  (code: 'ja', name: 'Japanese'),
  (code: 'kn', name: 'Kannada'),
  (code: 'ko', name: 'Korean'),
  (code: 'lt', name: 'Lithuanian'),
  (code: 'lv', name: 'Latvian'),
  (code: 'mk', name: 'Macedonian'),
  (code: 'mr', name: 'Marathi'),
  (code: 'ms', name: 'Malay'),
  (code: 'mt', name: 'Maltese'),
  (code: 'no', name: 'Norwegian'),
  (code: 'fa', name: 'Persian'),
  (code: 'pl', name: 'Polish'),
  (code: 'pt', name: 'Portuguese'),
  (code: 'ro', name: 'Romanian'),
  (code: 'ru', name: 'Russian'),
  (code: 'sk', name: 'Slovak'),
  (code: 'sl', name: 'Slovenian'),
  (code: 'es', name: 'Spanish'),
  (code: 'sv', name: 'Swedish'),
  (code: 'sw', name: 'Swahili'),
  (code: 'ta', name: 'Tamil'),
  (code: 'te', name: 'Telugu'),
  (code: 'th', name: 'Thai'),
  (code: 'tl', name: 'Tagalog'),
  (code: 'tr', name: 'Turkish'),
  (code: 'uk', name: 'Ukrainian'),
  (code: 'ur', name: 'Urdu'),
  (code: 'vi', name: 'Vietnamese'),
  (code: 'cy', name: 'Welsh'),
];

/// Friendly display name for a BCP-47 [code]; falls back to the upper-cased code
/// for anything not in [kTranslationLanguages].
String translationLanguageName(String code) {
  for (final l in kTranslationLanguages) {
    if (l.code == code) return l.name;
  }
  return code.toUpperCase();
}
