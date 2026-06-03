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

  test(
    'watchChatList orders by recency, carries the latest message as preview',
    () async {
      // Two chats; make the second the more-recently-updated one.
      final a = await repo.createChat('A');
      await repo.appendMessage(a, role: kRoleUser, content: 'a-q');
      await repo.appendMessage(a, role: kRoleAssistant, content: 'a-answer');
      await (db.update(db.chats)..where((t) => t.id.equals(a))).write(
        ChatsCompanion(updatedAt: Value(DateTime.utc(2001))),
      );

      final b = await repo.createChat('B');
      await repo.appendMessage(b, role: kRoleUser, content: 'b-q');
      await (db.update(db.chats)..where((t) => t.id.equals(b))).write(
        ChatsCompanion(updatedAt: Value(DateTime.utc(2002))),
      );

      final list = await repo.watchChatList(archived: false).first;
      expect(list.map((c) => c.id), [b, a]); // most-recent-first
      expect(list.first.preview, 'b-q'); // latest message
      expect(list.last.preview, 'a-answer');
      expect(list.every((c) => c.archived), isFalse);
    },
  );

  test('watchChatList splits active vs archived', () async {
    final active = await repo.createChat('active');
    final archived = await repo.createChat('archived');
    await repo.setArchived(archived, true);

    final activeList = await repo.watchChatList(archived: false).first;
    final archivedList = await repo.watchChatList(archived: true).first;
    expect(activeList.map((c) => c.id), [active]);
    expect(archivedList.map((c) => c.id), [archived]);
    expect(archivedList.single.archived, isTrue);
  });

  test('setArchived moves a chat between the two lists and back', () async {
    final id = await repo.createChat('c');
    await repo.setArchived(id, true);
    expect(
      (await repo.watchChatList(archived: false).first).map((c) => c.id),
      isEmpty,
    );
    expect((await repo.watchChatList(archived: true).first).map((c) => c.id), [
      id,
    ]);

    await repo.setArchived(id, false);
    final chat = await (db.select(
      db.chats,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(chat.archivedAt, isNull);
    expect((await repo.watchChatList(archived: false).first).map((c) => c.id), [
      id,
    ]);
  });

  test('renameChat updates the title; a blank rename is ignored', () async {
    final id = await repo.createChat('original');
    await repo.renameChat(id, '  new title  ');
    expect(await repo.watchChatTitle(id).first, 'new title');

    await repo.renameChat(id, '   ');
    expect(await repo.watchChatTitle(id).first, 'new title');
  });

  test('deleteChat removes the chat and cascades its messages', () async {
    final id = await repo.createChat('doomed');
    await repo.appendMessage(id, role: kRoleUser, content: 'q');
    await repo.appendMessage(id, role: kRoleAssistant, content: 'a');

    await repo.deleteChat(id);

    expect((await db.select(db.chats).get()), isEmpty);
    expect((await db.select(db.chatMessages).get()), isEmpty);
  });
}
