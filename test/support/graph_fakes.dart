import 'package:grabbit/core/ai/inference_engine.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/graph/graph_store.dart';

/// A scriptable [GraphStore] for tests: records every `runScript` call and
/// returns whatever [responder] yields (defaulting to an empty result).
class FakeGraphStore implements GraphStore {
  FakeGraphStore({this.available = true, this.responder});

  bool available;
  final Map<String, Object?> Function(String script)? responder;
  final List<({String script, Map<String, Object?> params})> calls = [];

  @override
  bool get isAvailable => available;

  @override
  Future<bool> open() async => available;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<void> close() async => available = false;

  @override
  Future<Map<String, Object?>> runScript(
    String script, [
    Map<String, Object?> params = const {},
  ]) async {
    calls.add((script: script, params: params));
    return responder?.call(script) ?? const {'rows': <List<Object?>>[]};
  }
}

/// A no-network [InferenceEngine] for tests. [ready] gates availability;
/// [embed] returns a constant zero vector of the right dimension.
class FakeInferenceEngine implements InferenceEngine {
  FakeInferenceEngine({this.ready = true});

  bool ready;
  int embedded = 0;

  @override
  EmbedderModel get model => geckoEmbedder;

  @override
  bool get isAvailable => ready;

  @override
  int get dimension => geckoEmbedder.dimension;

  @override
  Future<bool> ensureReady() async => ready;

  @override
  Future<void> downloadModel({
    void Function(double progress)? onProgress,
  }) async {}

  @override
  Future<List<double>> embed(String text) async {
    embedded++;
    return List<double>.filled(dimension, 0);
  }

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async => [
    for (final _ in texts) List<double>.filled(dimension, 0),
  ];

  @override
  Future<void> close() async {}
}
