import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/ai/data/chat_repository.dart';
import 'package:grabbit/features/ai/presentation/ask_chat.dart';

void main() {
  late AppDatabase db;
  late ChatRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ChatRepository(db);
  });
  tearDown(() => db.close());

  test(
    'createChat returns an id and stores the title; timestamps equal',
    () async {
      final id = await repo.createChat('What concerts have I saved?');
      final chat = await (db.select(
        db.chats,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(chat.title, 'What concerts have I saved?');
      expect(chat.createdAt, chat.updatedAt);
      expect(chat.archivedAt, isNull);
    },
  );

  test('appendMessage persists messages in order and bumps updatedAt', () async {
    final id = await repo.createChat('q1');
    // Force an old `updatedAt` so the bump is observable (DateTime is stored at
    // second resolution, so a wall-clock delay would be unreliable).
    await (db.update(db.chats)..where((t) => t.id.equals(id))).write(
      ChatsCompanion(updatedAt: Value(DateTime.utc(2000))),
    );

    await repo.appendMessage(id, role: kRoleUser, content: 'q1');
    await repo.appendMessage(
      id,
      role: kRoleAssistant,
      content: 'a1 [1]',
      citationsJson: '[{"i":1,"id":"x","title":"X"}]',
    );

    final msgs = await repo.messagesForChat(id);
    expect(msgs.map((m) => m.role), [kRoleUser, kRoleAssistant]);
    expect(msgs.map((m) => m.content), ['q1', 'a1 [1]']);
    expect(msgs.last.citationsJson, isNotNull);

    final after = await (db.select(
      db.chats,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(after.updatedAt.isAfter(DateTime.utc(2000)), isTrue);
  });

  test('watchMessages emits the ordered transcript', () async {
    final id = await repo.createChat('q');
    await repo.appendMessage(id, role: kRoleUser, content: 'q');
    await repo.appendMessage(id, role: kRoleAssistant, content: 'a');

    final msgs = await repo.watchMessages(id).first;
    expect(msgs.map((m) => m.content), ['q', 'a']);
  });
}
