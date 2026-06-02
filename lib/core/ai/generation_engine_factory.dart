import 'dart:io';

import 'package:grabbit/core/ai/flutter_gemma_generation_engine.dart';
import 'package:grabbit/core/ai/generation_engine.dart';
import 'package:grabbit/core/ai/generation_model.dart';
import 'package:grabbit/core/ai/unavailable_generation_engine.dart';
import 'package:grabbit/core/storage/disk_space_service.dart';

/// Maps a selected [GenerationModel] to the [GenerationEngine] that runs it on
/// this host — the runtime "registry" seam (mirrors `embedderEngineFor`). On
/// Android the real `flutter_gemma` engine runs it (P12d-2); other hosts (and a
/// missing [diskSpace]) fall back to the graceful [UnavailableGenerationEngine]
/// (generation stays off, never crashes), which still reports the selected
/// [model].
GenerationEngine generationEngineFor(
  GenerationModel model, {
  // Generation takes `diskSpace` (not a `ModelDownloadService` like the
  // file-based embedder/transcription factories) because flutter_gemma is
  // plugin-managed — it fetches its own model; we only need the free-space guard.
  DiskSpaceService? diskSpace,
}) {
  if (diskSpace != null && Platform.isAndroid) {
    return FlutterGemmaGenerationEngine(model, diskSpace: diskSpace);
  }
  return UnavailableGenerationEngine(model);
}
