import 'dart:io';

import 'package:grabbit/core/ai/flutter_gemma_inference_engine.dart';
import 'package:grabbit/core/ai/inference_engine.dart';
import 'package:grabbit/core/ai/unavailable_inference_engine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'inference_engine_provider.g.dart';

/// Selects the [InferenceEngine] for the host platform. UI and feature code
/// depend on this provider, never a concrete runtime (mirrors
/// `graph_store_provider.dart` / `engine_provider.dart`).
///
/// Unsupported platforms get [UnavailableInferenceEngine] (graceful
/// degradation, per docs/AI-SPEC.md) — semantic features simply stay off. The
/// engine is inert until the user opts in and downloads the model.
@Riverpod(keepAlive: true)
InferenceEngine inferenceEngine(Ref ref) {
  if (Platform.isAndroid) return FlutterGemmaInferenceEngine();
  return const UnavailableInferenceEngine();
}
