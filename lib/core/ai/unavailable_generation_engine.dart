import 'package:grabbit/core/ai/generation_engine.dart';
import 'package:grabbit/core/ai/generation_model.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/structured_generation.dart';

/// Graceful no-op [GenerationEngine] for devices/platforms that can't run
/// generation (low tier, non-Android, or before the native engine lands in
/// P12d-2). Never crashes — generation features simply stay off (AI-SPEC §1).
class UnavailableGenerationEngine implements GenerationEngine {
  const UnavailableGenerationEngine([this._model = qwen3_0_6b]);

  final GenerationModel _model;

  static const _ex = InferenceException(
    InferenceErrorCode.unavailable,
    'On-device text generation is not available on this device',
  );

  @override
  GenerationModel get model => _model;

  @override
  bool get isAvailable => false;

  @override
  Future<void> downloadModel({
    void Function(double progress)? onProgress,
  }) async => throw _ex;

  @override
  Future<bool> ensureReady() async => false;

  @override
  Stream<String> generate(String prompt, {String? systemPrompt}) =>
      Stream<String>.error(_ex);

  @override
  Future<StructuredResult> generateStructured(
    List<StructuredToolDef> toolDefs,
    String prompt, {
    String? systemPrompt,
  }) async => throw _ex;

  @override
  Future<void> close() async {}
}
