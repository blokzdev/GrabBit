import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/graph/graph_query_provider.dart';
import 'package:grabbit/core/graph/graph_query_service.dart';

/// A media item's graph neighborhood (connected entities + linked media) for the
/// graph-view render (P10c-e). Empty when the graph store is unavailable, so the
/// screen shows its unavailable/empty state. Deterministic edges — no embedder.
final graphNeighborhoodProvider =
    FutureProvider.family<List<GraphNeighbor>, String>((ref, itemId) {
      return ref.watch(graphQueryServiceProvider).neighborhood(itemId);
    });
