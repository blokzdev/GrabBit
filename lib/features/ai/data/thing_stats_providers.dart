import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/things/thing_edge_repository.dart';
import 'package:grabbit/core/things/thing_repository.dart';

/// Count of all Things, for the P14f AI-settings diagnostic. A **one-shot**
/// `.get()` read (via `autoDispose`, so it refreshes each time the screen opens)
/// rather than a live `.watch()` stream — a settings diagnostic doesn't need to
/// tick live, and a one-shot read leaves **no pending drift query timer** to trip
/// widget-test teardown (`!timersPending`).
final thingCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(thingRepositoryProvider).countThings(),
);

/// Count of all authored Thing→Thing edges (P14f diagnostic). One-shot, as above.
final thingEdgeCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(thingEdgeRepositoryProvider).countEdges(),
);
