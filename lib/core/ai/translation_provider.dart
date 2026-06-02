import 'package:grabbit/core/ai/translation_engine.dart';
import 'package:grabbit/core/ai/translation_engine_factory.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'translation_provider.g.dart';

/// The [TranslationEngine] for this host (P13b-2). Routes via
/// `translationEngineFor`; an unsupported platform yields the graceful
/// [UnavailableTranslationEngine]. No device-tier gating (ML Kit translation
/// runs on any Android device; models download on demand over HTTPS).
@Riverpod(keepAlive: true)
TranslationEngine translationEngine(Ref ref) => translationEngineFor();
