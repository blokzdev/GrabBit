import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/presentation/dedupe_actions.dart';

MediaItem _item(String id) => MediaItem(
  id: id,
  title: id,
  sourceUrl: 'https://y/$id',
  site: 'youtube',
  filePath: '/m/$id',
  type: 'video',
  createdAt: DateTime.utc(2026),
  storageState: 'private',
  isFavorite: false,
);

void main() {
  test('keeps the first (oldest) of each group, returns the rest', () {
    final remove = duplicatesToRemove([
      [_item('a'), _item('b'), _item('c')],
      [_item('d'), _item('e')],
    ]);
    expect(remove.map((i) => i.id), ['b', 'c', 'e']);
  });

  test('nothing to remove for empty or single-item groups', () {
    expect(duplicatesToRemove(const []), isEmpty);
    expect(
      duplicatesToRemove([
        [_item('a')],
      ]),
      isEmpty,
    );
  });
}
