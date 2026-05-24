import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/graph/graph_store_provider.dart';
import 'package:grabbit/core/graph/graph_sync_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'graph_sync_provider.g.dart';

/// The graph sync service, started for the app's lifetime. Reading it begins the
/// debounced Drift-update listener that keeps the Cozo graph in sync with the
/// canonical library.
@Riverpod(keepAlive: true)
GraphSyncService graphSyncService(Ref ref) {
  final service = GraphSyncService(
    ref.watch(graphStoreProvider),
    ref.watch(appDatabaseProvider),
  );
  service.start();
  ref.onDispose(service.dispose);
  return service;
}
