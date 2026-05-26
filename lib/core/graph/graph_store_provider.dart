import 'dart:io';

import 'package:grabbit/core/graph/android_cozo_graph_store.dart';
import 'package:grabbit/core/graph/graph_store.dart';
import 'package:grabbit/core/graph/unavailable_graph_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'graph_store_provider.g.dart';

/// Selects the [GraphStore] for the host platform. UI and feature code depend on
/// this provider, never a concrete engine (mirrors `engine_provider.dart`).
///
/// Unsupported platforms get [UnavailableGraphStore] (graceful degradation, per
/// docs/AI-SPEC.md) rather than an error — the Windows `dart:ffi` impl replaces
/// it in P15.
@Riverpod(keepAlive: true)
GraphStore graphStore(Ref ref) {
  if (Platform.isAndroid) return AndroidCozoGraphStore();
  return const UnavailableGraphStore();
}
