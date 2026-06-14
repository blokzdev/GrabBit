import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/things/thing_edge_repository.dart';
import 'package:grabbit/core/things/thing_repository.dart';

/// Live count of all Things (P14f diagnostic). Hand-written — wraps the repo's
/// `watchThingCount()` stream.
final thingCountProvider = StreamProvider<int>(
  (ref) => ref.watch(thingRepositoryProvider).watchThingCount(),
);

/// Live count of all authored Thing→Thing edges (P14f diagnostic).
final thingEdgeCountProvider = StreamProvider<int>(
  (ref) => ref.watch(thingEdgeRepositoryProvider).watchEdgeCount(),
);
