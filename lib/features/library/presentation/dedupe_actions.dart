import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/data/library_repository.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// The extra copies to delete when resolving duplicates: every item in each
/// group except the first. `watchDuplicates` orders each group oldest-first, so
/// this keeps the original and drops the later copies. Pure — unit-testable.
List<MediaItem> duplicatesToRemove(List<List<MediaItem>> groups) => [
  for (final group in groups) ...group.skip(1),
];

/// Bulk-resolves duplicates: deletes every extra copy (keeping the oldest of
/// each group) through the normal delete path, honoring the secure-delete
/// setting. Returns how many items were removed.
Future<int> resolveDuplicates(WidgetRef ref) async {
  final groups = ref.read(duplicatesProvider).value ?? const [];
  final toRemove = duplicatesToRemove(groups);
  if (toRemove.isEmpty) return 0;
  final secure =
      ref.read(settingsControllerProvider).asData?.value.secureDelete ?? false;
  final repo = ref.read(libraryRepositoryProvider);
  for (final item in toRemove) {
    await repo.deleteItem(item, secure: secure);
  }
  return toRemove.length;
}
