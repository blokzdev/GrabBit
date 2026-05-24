import 'package:grabbit/core/graph/graph_error.dart';
import 'package:grabbit/core/graph/graph_store.dart';

/// Graceful no-op [GraphStore] for platforms without a native engine yet —
/// Windows (its `dart:ffi` impl lands in P14) and any other host. [isAvailable]
/// is always false, so callers disable graph features cleanly; mutating calls
/// throw [GraphErrorCode.unavailable] rather than crash.
class UnavailableGraphStore implements GraphStore {
  const UnavailableGraphStore();

  static const _ex = GraphException(
    GraphErrorCode.unavailable,
    'Graph store is not available on this platform',
  );

  @override
  bool get isAvailable => false;

  @override
  Future<bool> open() async => false;

  @override
  Future<Map<String, Object?>> runScript(
    String script, [
    Map<String, Object?> params = const {},
  ]) async => throw _ex;

  @override
  Future<void> ensureSchema() async => throw _ex;

  @override
  Future<void> close() async {}
}
