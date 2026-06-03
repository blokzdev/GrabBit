import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';

/// Persistence for the "Ask your library" GraphRAG chat (P13d-2a): a thread of
/// [Chat]s, each a list of ordered [ChatMessage]s. Drift stays canonical; this
/// repo only reads/writes the `chats` + `chat_messages` tables. The conversation
/// list + rename/archive/delete land in d-2b on the same schema.
class ChatRepository {
  ChatRepository(this._db);

  final AppDatabase _db;

  /// Creates a new chat with [title] (derived from the first question) and
  /// returns its id. `createdAt`/`updatedAt` start equal.
  Future<String> createChat(String title) async {
    final now = DateTime.now();
    final id = 'chat_${now.microsecondsSinceEpoch}';
    await _db
        .into(_db.chats)
        .insert(
          ChatsCompanion.insert(
            id: id,
            title: title,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Appends a message to [chatId] and bumps the chat's `updatedAt` (so the
  /// d-2b list sorts most-recent-first). [citationsJson] is set on assistant
  /// turns only.
  Future<void> appendMessage(
    String chatId, {
    required String role,
    required String content,
    String? citationsJson,
  }) async {
    await _db.transaction(() async {
      await _db
          .into(_db.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              chatId: chatId,
              role: role,
              content: content,
              citationsJson: Value(citationsJson),
              createdAt: DateTime.now(),
            ),
          );
      await (_db.update(_db.chats)..where((t) => t.id.equals(chatId))).write(
        ChatsCompanion(updatedAt: Value(DateTime.now())),
      );
    });
  }

  /// Live transcript for [chatId], ordered oldest-first.
  Stream<List<ChatMessage>> watchMessages(String chatId) =>
      (_db.select(_db.chatMessages)
            ..where((t) => t.chatId.equals(chatId))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .watch();

  /// One-shot read of [chatId]'s messages (oldest-first) — used to build the
  /// bounded history window for the next turn's prompt.
  Future<List<ChatMessage>> messagesForChat(String chatId) =>
      (_db.select(_db.chatMessages)
            ..where((t) => t.chatId.equals(chatId))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(appDatabaseProvider)),
);

/// Live transcript provider. Hand-written (returns the Drift row type
/// [ChatMessage]) per CLAUDE.md §8 — `riverpod_generator` can't return rows.
final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>(
  (ref, chatId) => ref.watch(chatRepositoryProvider).watchMessages(chatId),
);
