import 'package:grabbit/core/ai/generation_engine.dart';
import 'package:grabbit/core/ai/generation_model.dart';
import 'package:grabbit/core/ai/unavailable_generation_engine.dart';

/// Maps a selected [GenerationModel] to the [GenerationEngine] that runs it on
/// this host — the runtime "registry" seam (mirrors `embedderEngineFor`). The
/// real `FlutterGemmaGenerationEngine` lands in **P12d-2**; until then every
/// model routes to the graceful [UnavailableGenerationEngine] (generation stays
/// off, never crashes), which still reports the selected [model].
GenerationEngine generationEngineFor(GenerationModel model) =>
    UnavailableGenerationEngine(model);
