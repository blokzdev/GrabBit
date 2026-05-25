import 'package:grabbit/core/graph/graph_query_service.dart';
import 'package:grabbit/core/graph/graph_store_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'graph_query_provider.g.dart';

/// The read-side graph query service over the host [GraphStore]. UI/feature code
/// depends on this, never a concrete engine (mirrors `graphStoreProvider` /
/// `graphSyncServiceProvider`).
@Riverpod(keepAlive: true)
GraphQueryService graphQueryService(Ref ref) =>
    GraphQueryService(ref.watch(graphStoreProvider));
