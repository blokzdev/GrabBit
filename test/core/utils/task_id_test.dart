import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/utils/task_id.dart';

void main() {
  group('newTaskId', () {
    test('is prefixed and never collides across rapid mints', () {
      final ids = [for (var i = 0; i < 10000; i++) newTaskId()];
      expect(ids.every((id) => id.startsWith('dl_')), isTrue);
      expect(ids.toSet().length, ids.length);
    });
  });
}
