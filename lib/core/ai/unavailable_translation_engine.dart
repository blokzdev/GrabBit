import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/translation_engine.dart';

/// Graceful no-op [TranslationEngine] for hosts that can't run ML Kit
/// translation (non-Android until P15, CI). Never crashes — translation simply
/// stays unavailable (AI-SPEC §1); the "Translate…" action is hidden when
/// `isAvailable` is false.
class UnavailableTranslationEngine implements TranslationEngine {
  const UnavailableTranslationEngine();

  static const _ex = InferenceException(
    InferenceErrorCode.unavailable,
    'On-device translation is not available on this device',
  );

  @override
  bool get isAvailable => false;

  @override
  Future<String> identifyLanguage(String text) async => 'und';

  @override
  Future<bool> isModelDownloaded(String code) async => false;

  @override
  Future<void> downloadModel(String code, {bool requireWifi = true}) =>
      throw _ex;

  @override
  Future<String> translate(
    String text, {
    required String source,
    required String target,
  }) => throw _ex;

  @override
  Future<void> close() async {}
}
