import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';

/// A conversation as shown in the chat list (P13d-2b): the chat's id/title, when
/// it was last touched, the latest message as a preview, and whether it's
/// archived. A lightweight projection (not the full [Chat] row) so the list query
/// stays a single statement with no per-row follow-up reads.
class ChatListItem {
  const ChatListItem({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.preview,
    required this.archived,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final String? preview;
  final bool archived;
}

/// Persistence for the "Ask your library" GraphRAG chat (P13d-2a/b): a thread of
/// [Chat]s, each a list of ordered [ChatMessage]s. Drift stays canonical; this
/// repo only reads/writes the `chats` + `chat_messages` tables. d-2b adds the
/// conversation list + rename/archive/delete on the same v14 schema.
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

  /// Live conversation list (P13d-2b), most-recent-first, filtered by
  /// [archived]. One reactive statement with a correlated subquery for each
  /// chat's latest message (the list preview) — no per-row follow-up reads.
  Stream<List<ChatListItem>> watchChatList({required bool archived}) {
    final archivedClause = archived
        ? 'archived_at IS NOT NULL'
        : 'archived_at IS NULL';
    return _db
        .customSelect(
          // `chats.*` so Drift's generated mapper decodes the row (incl. the
          // DateTime format); `preview` is the latest message via a correlated
          // subquery — one statement, no per-row follow-up read.
          'SELECT chats.*, '
          '(SELECT content FROM chat_messages m WHERE m.chat_id = chats.id '
          'ORDER BY m.id DESC LIMIT 1) AS preview '
          'FROM chats WHERE $archivedClause ORDER BY updated_at DESC',
          readsFrom: {_db.chats, _db.chatMessages},
        )
        .watch()
        .map((rows) {
          return rows.map((row) {
            final chat = _db.chats.map(row.data);
            return ChatListItem(
              id: chat.id,
              title: chat.title,
              updatedAt: chat.updatedAt,
              preview: row.read<String?>('preview'),
              archived: archived,
            );
          }).toList();
        });
  }

  /// Live title for [chatId] (null if the chat doesn't exist yet) — drives the
  /// chat screen's app bar so a rename reflects immediately.
  Stream<String?> watchChatTitle(String chatId) =>
      (_db.select(_db.chats)..where((t) => t.id.equals(chatId)))
          .watchSingleOrNull()
          .map((c) => c?.title);

  /// Renames [chatId]; a blank title is ignored (keeps the derived one).
  Future<void> renameChat(String chatId, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    await (_db.update(_db.chats)..where((t) => t.id.equals(chatId))).write(
      ChatsCompanion(title: Value(trimmed)),
    );
  }

  /// Archives (hides from the active list, kept + restorable) or unarchives
  /// [chatId] by setting/clearing `archivedAt`.
  Future<void> setArchived(String chatId, bool archived) async {
    await (_db.update(_db.chats)..where((t) => t.id.equals(chatId))).write(
      ChatsCompanion(archivedAt: Value(archived ? DateTime.now() : null)),
    );
  }

  /// Deletes [chatId]; its messages cascade (the `chat_messages` FK).
  Future<void> deleteChat(String chatId) async {
    await (_db.delete(_db.chats)..where((t) => t.id.equals(chatId))).go();
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(appDatabaseProvider)),
);

/// Live transcript provider. Hand-written (returns the Drift row type
/// [ChatMessage]) per CLAUDE.md §8 — `riverpod_generator` can't return rows.
final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>(
  (ref, chatId) => ref.watch(chatRepositoryProvider).watchMessages(chatId),
);

/// Active (non-archived) conversations for the chat list (P13d-2b),
/// most-recent-first.
final activeChatsProvider = StreamProvider<List<ChatListItem>>(
  (ref) => ref.watch(chatRepositoryProvider).watchChatList(archived: false),
);

/// Archived conversations (kept + restorable), most-recent-first.
final archivedChatsProvider = StreamProvider<List<ChatListItem>>(
  (ref) => ref.watch(chatRepositoryProvider).watchChatList(archived: true),
);

/// Live title of a single conversation, for the chat screen's app bar.
final chatTitleProvider = StreamProvider.family<String?, String>(
  (ref, chatId) => ref.watch(chatRepositoryProvider).watchChatTitle(chatId),
);
