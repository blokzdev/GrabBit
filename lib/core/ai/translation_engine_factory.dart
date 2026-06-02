import 'dart:io';

import 'package:grabbit/core/ai/ml_kit_translation_engine.dart';
import 'package:grabbit/core/ai/translation_engine.dart';
import 'package:grabbit/core/ai/unavailable_translation_engine.dart';

/// Maps the host platform to its [TranslationEngine] — the runtime "registry"
/// seam (mirrors `ocrEngineFor`). Android gets the real ML Kit engine; every
/// other host gets the graceful [UnavailableTranslationEngine].
TranslationEngine translationEngineFor() => Platform.isAndroid
    ? MlKitTranslationEngine()
    : const UnavailableTranslationEngine();
