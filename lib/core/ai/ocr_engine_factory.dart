import 'dart:io';

import 'package:grabbit/core/ai/ml_kit_ocr_engine.dart';
import 'package:grabbit/core/ai/ocr_engine.dart';
import 'package:grabbit/core/ai/unavailable_ocr_engine.dart';

/// Maps the host platform to its [OcrEngine] — the runtime "registry" seam
/// (mirrors `transcriptionEngineFor`). Android gets the real ML Kit engine;
/// every other host gets the graceful [UnavailableOcrEngine] (OCR stays off,
/// never crashes).
OcrEngine ocrEngineFor() =>
    Platform.isAndroid ? MlKitOcrEngine() : const UnavailableOcrEngine();
