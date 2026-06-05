import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/ai/model_download_service.dart';

/// The ids of AI models with cached files on disk (P13f-1) — drives the
/// "Downloaded / Active / tap to download" state on the model-picker tiles.
/// Existence-based (cheap); invalidate after a download or delete to refresh.
final downloadedModelIdsProvider = FutureProvider<Set<String>>(
  (ref) => ref.watch(modelDownloadServiceProvider).installedModelIds(),
);
