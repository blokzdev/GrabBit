import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';

// Manual providers (not riverpod_generator): the generator currently can't
// resolve Drift's generated `MediaItem` row type in a provider return
// signature (InvalidTypeException).

/// Live stream of saved library items, newest first.
final libraryItemsProvider = StreamProvider<List<MediaItem>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.mediaItems)
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
  return query.watch();
});

final mediaItemByIdProvider = FutureProvider.family<MediaItem?, String>((
  ref,
  id,
) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(
    db.mediaItems,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
});
