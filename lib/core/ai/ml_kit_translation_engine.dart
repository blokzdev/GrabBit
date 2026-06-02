import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/translation_engine.dart';

/// Maps a BCP-47 [code] to ML Kit's [TranslateLanguage], or null when the
/// language isn't supported by on-device translation. Pure (no native calls) —
/// the testable core of the engine's language handling.
TranslateLanguage? translateLanguageForCode(String code) =>
    BCP47Code.fromRawValue(code.trim().toLowerCase());

/// Android [TranslationEngine] backed by ML Kit on-device translation +
/// language identification (P13b-2). No Google Play Services: models download
/// over HTTPS via [OnDeviceTranslatorModelManager] and run offline after. A
/// translator/identifier is created per call and closed (translation is
/// on-demand and infrequent, so there's no persistent native handle to leak).
class MlKitTranslationEngine implements TranslationEngine {
  final OnDeviceTranslatorModelManager _models =
      OnDeviceTranslatorModelManager();

  @override
  bool get isAvailable => true;

  @override
  Future<String> identifyLanguage(String text) async {
    final identifier = LanguageIdentifier(confidenceThreshold: 0.5);
    try {
      return await identifier.identifyLanguage(text);
    } on Exception {
      return 'und';
    } finally {
      await identifier.close();
    }
  }

  @override
  Future<bool> isModelDownloaded(String code) async {
    final lang = translateLanguageForCode(code);
    if (lang == null) return false;
    return _models.isModelDownloaded(lang.bcpCode);
  }

  @override
  Future<void> downloadModel(String code, {bool requireWifi = true}) async {
    final lang = translateLanguageForCode(code);
    if (lang == null) {
      throw InferenceException(
        InferenceErrorCode.unavailable,
        'Translation to "$code" is not supported on this device',
      );
    }
    try {
      await _models.downloadModel(lang.bcpCode, isWifiRequired: requireWifi);
    } on Exception catch (e) {
      throw InferenceException(
        InferenceErrorCode.downloadFailed,
        'Could not download the "$code" language pack',
        cause: e,
      );
    }
  }

  @override
  Future<String> translate(
    String text, {
    required String source,
    required String target,
  }) async {
    final from = translateLanguageForCode(source);
    final to = translateLanguageForCode(target);
    if (from == null || to == null) {
      throw const InferenceException(
        InferenceErrorCode.unavailable,
        'That language pair is not supported on this device',
      );
    }
    final translator = OnDeviceTranslator(
      sourceLanguage: from,
      targetLanguage: to,
    );
    try {
      return await translator.translateText(text);
    } on Exception catch (e) {
      throw InferenceException(
        InferenceErrorCode.translateFailed,
        'Translation failed',
        cause: e,
      );
    } finally {
      await translator.close();
    }
  }

  @override
  Future<void> close() async {}
}
