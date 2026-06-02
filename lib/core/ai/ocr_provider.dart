import 'package:grabbit/core/ai/ocr_engine.dart';
import 'package:grabbit/core/ai/ocr_engine_factory.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ocr_provider.g.dart';

/// The [OcrEngine] for this host (P13b-1). Routes via `ocrEngineFor`; an
/// unsupported platform yields the graceful [UnavailableOcrEngine] — OCR simply
/// stays off, never crashes. No model download or device-tier gating (the
/// bundled Latin model runs offline on any Android device).
@Riverpod(keepAlive: true)
OcrEngine ocrEngine(Ref ref) => ocrEngineFor();
