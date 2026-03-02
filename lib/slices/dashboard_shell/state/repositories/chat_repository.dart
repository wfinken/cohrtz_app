import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:cohortz/shared/database/database.dart';
import 'package:cohortz/shared/utils/logging_service.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/sync/runtime/hybrid_time_service.dart';

import 'room_repository_base.dart';

abstract class IChatRepository {
  Stream<List<ChatMessage>> watchMessages({String? threadId});
  Stream<List<ChatMessage>> watchMessagesForThread(String threadId);
  Future<void> saveMessage(ChatMessage message);
  Future<ChatMessage?> getMessageById(String messageId);
  Future<void> editMessage({
    required String messageId,
    required String editorId,
    required String content,
  });
  Future<void> softDeleteMessage({
    required String messageId,
    required String deletedBy,
  });
  Future<void> toggleReaction({
    required String messageId,
    required String emoji,
    required String userId,
  });
  Future<void> togglePin({
    required String messageId,
    required bool pinned,
    required String actorId,
  });
  Stream<List<ChatThread>> watchChatThreads();
  Future<void> saveChatThread(ChatThread thread);
  Future<void> deleteChatThread(String threadId);
  Future<ChatThread> createSubthreadFromMessage({
    required String parentMessageId,
    required String creatorId,
    required String name,
  });
  Future<void> leaveDirectMessageThread({
    required String threadId,
    required String userId,
  });
  Future<void> deleteChatThreadAndMessages(String threadId);
  Future<void> clearChatMessages(String threadId);
  Stream<List<ChatTypingState>> watchTypingStates(
    String threadId, {
    Duration activeThreshold = const Duration(seconds: 7),
  });
  Future<void> touchTyping({
    required String threadId,
    required String userId,
    required bool isTyping,
  });
  Stream<List<ChatUserPresence>> watchPresence({
    Duration activeThreshold = const Duration(minutes: 2),
  });
  Future<void> touchPresence({required String userId, required String state});
  Stream<List<ChatModerationEvent>> watchModerationEvents({
    String? threadId,
    String? targetUserId,
  });
  Future<void> saveModerationEvent(ChatModerationEvent event);
  Future<List<ChatSearchResult>> searchMessages(
    ChatSearchQuery query, {
    int limit = 100,
  });
  Future<ChatThread> ensureDirectMessageThread({
    required String localUserId,
    required String peerUserId,
  });
}

class ChatRepository extends RoomRepositoryBase implements IChatRepository {
  final HybridTimeService _hybridTimeService;

  static const String _messageIdPrefix = 'msg:';
  static const String _threadIdPrefix = 'chat:';
  static const String _typingIdPrefix = 'typing:';
  static const String _presenceIdPrefix = 'presence:';
  static const String _moderationIdPrefix = 'mod:';

  const ChatRepository(
    super.crdtService,
    super.roomName,
    this._hybridTimeService,
  );

  @override
  Stream<List<ChatMessage>> watchMessages({String? threadId}) {
    final activeDb = db;
    final activeRoom = roomName;
    if (activeDb == null) {
      if (activeRoom == null) return Stream.value(const <ChatMessage>[]);
      final threadNeedle = threadId == null ? null : '"threadId":"$threadId"';
      final defaultNeedle = threadId == ChatThread.generalId
          ? '"threadId":"${ChatMessage.defaultThreadId}"'
          : null;
      return crdtService
          .watch(
            activeRoom,
            "SELECT id, value FROM chat_messages WHERE is_deleted = 0 AND id LIKE '$_messageIdPrefix%'",
          )
          .map((rows) {
            return _deserializeAndSortMessages(
              rows.map((row) {
                final id = row['id'] as String? ?? '';
                final value = row['value'] as String? ?? '';
                return (id: id, value: value);
              }).toList(),
              threadNeedle: threadNeedle,
              defaultNeedle: defaultNeedle,
            );
          });
    }

    final threadNeedle = threadId == null ? null : '"threadId":"$threadId"';
    final defaultNeedle = threadId == ChatThread.generalId
        ? '"threadId":"${ChatMessage.defaultThreadId}"'
        : null;

    return (activeDb.select(activeDb.chatMessages)
          ..where((t) => t.isDeleted.equals(0))
          ..where((t) => t.id.like('$_messageIdPrefix%')))
        .watch()
        .map((rows) {
          return _deserializeAndSortMessages(
            rows.map((row) => (id: row.id, value: row.value)).toList(),
            threadNeedle: threadNeedle,
            defaultNeedle: defaultNeedle,
          );
        });
  }

  @override
  Stream<List<ChatMessage>> watchMessagesForThread(String threadId) {
    return watchMessages(threadId: threadId);
  }

  @override
  Future<void> saveMessage(ChatMessage message) async {
    final activeDb = db;
    final activeRoom = roomName;
    if (activeDb == null) {
      if (activeRoom == null) return;
      await crdtService.put(
        activeRoom,
        message.id,
        jsonEncode(message.toMap()),
        tableName: 'chat_messages',
      );
      await _touchThreadActivity(message.threadId, message.timestamp);
      return;
    }
    await activeDb
        .into(activeDb.chatMessages)
        .insertOnConflictUpdate(
          ChatMessageEntity(
            id: message.id,
            value: jsonEncode(message.toMap()),
            isDeleted: 0,
          ),
        );
    await _touchThreadActivity(message.threadId, message.timestamp);
  }

  @override
  Future<ChatMessage?> getMessageById(String messageId) async {
    if (messageId.isEmpty) return null;
    final activeDb = db;
    final activeRoom = roomName;
    if (activeDb == null) {
      if (activeRoom == null) return null;
      final rows = await crdtService.query(
        activeRoom,
        'SELECT value FROM chat_messages WHERE id = ? AND is_deleted = 0',
        [messageId],
      );
      if (rows.isEmpty) return null;
      final value = rows.first['value'] as String? ?? '';
      if (value.isEmpty) return null;
      try {
        return ChatMessageMapper.fromJson(value);
      } catch (_) {
        return null;
      }
    }

    final row =
        await (activeDb.select(activeDb.chatMessages)
              ..where((t) => t.id.equals(messageId))
              ..where((t) => t.isDeleted.equals(0)))
            .getSingleOrNull();
    if (row == null) return null;
    try {
      return ChatMessageMapper.fromJson(row.value);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> editMessage({
    required String messageId,
    required String editorId,
    required String content,
  }) async {
    if (editorId.isEmpty || content.trim().isEmpty) return;
    final existing = await getMessageById(messageId);
    if (existing == null || existing.isDeleted) return;
    await saveMessage(
      existing.copyWith(
        content: content.trim(),
        editedAt: _hybridTimeService.getAdjustedTimeLocal(),
        logicalTime: _hybridTimeService.nextLogicalTime(),
      ),
    );
  }

  @override
  Future<void> softDeleteMessage({
    required String messageId,
    required String deletedBy,
  }) async {
    if (deletedBy.isEmpty) return;
    final existing = await getMessageById(messageId);
    if (existing == null || existing.isDeleted) return;
    await saveMessage(
      existing.copyWith(
        deletedAt: _hybridTimeService.getAdjustedTimeLocal(),
        deletedBy: deletedBy,
        logicalTime: _hybridTimeService.nextLogicalTime(),
      ),
    );
  }

  @override
  Future<void> toggleReaction({
    required String messageId,
    required String emoji,
    required String userId,
  }) async {
    if (emoji.trim().isEmpty || userId.isEmpty) return;
    final existing = await getMessageById(messageId);
    if (existing == null || existing.isDeleted) return;

    final normalizedEmoji = emoji.trim();
    final reactions = <String, List<String>>{
      for (final entry in existing.reactions.entries)
        entry.key: List<String>.from(entry.value),
    };

    final users = reactions[normalizedEmoji] ?? <String>[];
    if (users.contains(userId)) {
      users.removeWhere((id) => id == userId);
    } else {
      users.add(userId);
      users.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }

    if (users.isEmpty) {
      reactions.remove(normalizedEmoji);
    } else {
      reactions[normalizedEmoji] = users;
    }

    await saveMessage(
      existing.copyWith(
        reactions: reactions,
        logicalTime: _hybridTimeService.nextLogicalTime(),
      ),
    );
  }

  @override
  Future<void> togglePin({
    required String messageId,
    required bool pinned,
    required String actorId,
  }) async {
    if (actorId.isEmpty) return;
    final existing = await getMessageById(messageId);
    if (existing == null || existing.isDeleted) return;

    await saveMessage(
      existing.copyWith(
        isPinned: pinned,
        pinnedAt: pinned ? _hybridTimeService.getAdjustedTimeLocal() : null,
        pinnedBy: pinned ? actorId : null,
        logicalTime: _hybridTimeService.nextLogicalTime(),
      ),
    );
  }

  @override
  Stream<List<ChatThread>> watchChatThreads() {
    final activeDb = db;
    final activeRoom = roomName;
    if (activeDb == null) {
      if (activeRoom == null) return Stream.value(const <ChatThread>[]);
      return crdtService
          .watch(
            activeRoom,
            "SELECT value FROM chat_threads WHERE is_deleted = 0 AND id LIKE '$_threadIdPrefix%'",
          )
          .map(
            (rows) => _deserializeAndSortThreads(
              rows.map((row) {
                final value = row['value'] as String? ?? '';
                return (value: value);
              }).toList(),
            ),
          );
    }

    return (activeDb.select(activeDb.chatThreads)
          ..where((t) => t.isDeleted.equals(0))
          ..where((t) => t.id.like('$_threadIdPrefix%')))
        .watch()
        .map(
          (rows) => _deserializeAndSortThreads(
            rows.map((row) {
              return (value: row.value);
            }).toList(),
          ),
        );
  }

  @override
  Future<void> saveChatThread(ChatThread thread) async {
    final activeDb = db;
    final activeRoom = roomName;
    if (activeDb == null) {
      if (activeRoom == null) return;
      await crdtService.put(
        activeRoom,
        thread.id,
        jsonEncode(thread.toMap()),
        tableName: 'chat_threads',
      );
      return;
    }
    await activeDb
        .into(activeDb.chatThreads)
        .insertOnConflictUpdate(
          ChatThreadEntity(
            id: thread.id,
            value: jsonEncode(thread.toMap()),
            isDeleted: 0,
          ),
        );
  }

  @override
  Future<void> deleteChatThread(String threadId) =>
      crdtDelete(threadId, 'chat_threads');

  @override
  Future<ChatThread> createSubthreadFromMessage({
    required String parentMessageId,
    required String creatorId,
    required String name,
  }) async {
    final parent = await getMessageById(parentMessageId);
    if (parent == null) {
      throw StateError('Parent message not found for subthread.');
    }

    final logicalTime = _hybridTimeService.nextLogicalTime();
    final now = _hybridTimeService.getAdjustedTimeLocal();
    final normalizedName = name.trim().isEmpty ? 'thread' : name.trim();

    final thread = ChatThread(
      id: 'chat:thread:${_encodeKeyPart(parentMessageId)}:$logicalTime',
      kind: ChatThread.subthreadKind,
      name: normalizedName,
      participantIds: const [],
      createdBy: creatorId,
      createdAt: now,
      logicalTime: logicalTime,
      parentChannelId: parent.threadId,
      parentMessageId: parentMessageId,
      memberIds: creatorId.isEmpty ? const [] : <String>[creatorId],
      lastActivityAt: now,
    );

    await saveChatThread(thread);
    return thread;
  }

  @override
  Future<void> leaveDirectMessageThread({
    required String threadId,
    required String userId,
  }) async {
    if (userId.isEmpty) return;
    final thread = await _loadThreadById(threadId);
    if (thread == null ||
        !thread.isDm ||
        !thread.participantIds.contains(userId)) {
      return;
    }

    final nextParticipants = thread.participantIds
        .where((id) => id != userId)
        .toList(growable: false);
    if (nextParticipants.isEmpty) {
      await deleteChatThreadAndMessages(threadId);
      return;
    }

    await saveChatThread(thread.copyWith(participantIds: nextParticipants));
  }

  @override
  Future<void> deleteChatThreadAndMessages(String threadId) async {
    final activeDb = db;
    final activeRoom = roomName;
    if (activeRoom == null) return;

    final rows = activeDb == null
        ? await crdtService.query(
            activeRoom,
            "SELECT id, value FROM chat_messages WHERE is_deleted = 0 AND id LIKE '$_messageIdPrefix%'",
          )
        : (await (activeDb.select(
                activeDb.chatMessages,
              )..where((t) => t.id.like('$_messageIdPrefix%'))).get())
              .map((row) => <String, String>{'id': row.id, 'value': row.value})
              .toList();

    for (final row in rows) {
      final value = row['value'] as String? ?? '';
      if (value.isEmpty) continue;
      try {
        final message = ChatMessageMapper.fromJson(value);
        if (message.threadId != threadId) continue;
        final id = row['id'] as String?;
        if (id == null || id.isEmpty) continue;
        await crdtDelete(id, 'chat_messages');
      } catch (_) {}
    }

    await deleteChatThread(threadId);
  }

  @override
  Future<void> clearChatMessages(String threadId) async {
    final activeDb = db;
    final activeRoom = roomName;
    if (activeRoom == null) return;

    final rows = activeDb == null
        ? await crdtService.query(
            activeRoom,
            "SELECT id, value FROM chat_messages WHERE is_deleted = 0 AND id LIKE '$_messageIdPrefix%'",
          )
        : (await (activeDb.select(
                activeDb.chatMessages,
              )..where((t) => t.id.like('$_messageIdPrefix%'))).get())
              .map((row) => <String, String>{'id': row.id, 'value': row.value})
              .toList();

    for (final row in rows) {
      final value = row['value'] as String? ?? '';
      if (value.isEmpty) continue;
      try {
        final message = ChatMessageMapper.fromJson(value);
        if (message.threadId != threadId) continue;
        final id = row['id'] as String?;
        if (id == null || id.isEmpty) continue;
        await crdtDelete(id, 'chat_messages');
      } catch (_) {}
    }
  }

  @override
  Stream<List<ChatTypingState>> watchTypingStates(
    String threadId, {
    Duration activeThreshold = const Duration(seconds: 7),
  }) {
    final activeDb = db;
    final activeRoom = roomName;
    final pattern = '$_typingIdPrefix${_encodeKeyPart(threadId)}:%';

    final Stream<List<dynamic>> source = activeDb == null
        ? (activeRoom == null
              ? Stream.value(const <dynamic>[])
              : crdtService.watch(
                  activeRoom,
                  "SELECT id, value FROM chat_messages WHERE is_deleted = 0 AND id LIKE '$pattern'",
                ))
        : (activeDb.select(activeDb.chatMessages)
                ..where((t) => t.isDeleted.equals(0))
                ..where((t) => t.id.like(pattern)))
              .watch();

    return source.map((rows) {
      final now = _hybridTimeService.getAdjustedTimeLocal();
      final states = rows
          .map((row) {
            final raw = activeDb == null
                ? (row['value'] as String? ?? '')
                : row.value;
            if (raw.isEmpty) return null;
            try {
              return ChatTypingStateMapper.fromJson(raw);
            } catch (_) {
              return null;
            }
          })
          .whereType<ChatTypingState>()
          .where((state) => state.isTyping)
          .where(
            (state) => now.difference(state.lastActiveAt) <= activeThreshold,
          )
          .toList();
      states.sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));
      return states;
    });
  }

  @override
  Future<void> touchTyping({
    required String threadId,
    required String userId,
    required bool isTyping,
  }) async {
    if (threadId.isEmpty || userId.isEmpty) return;
    final activeDb = db;
    final activeRoom = roomName;

    final state = ChatTypingState(
      threadId: threadId,
      userId: userId,
      lastActiveAt: _hybridTimeService.getAdjustedTimeLocal(),
      isTyping: isTyping,
      logicalTime: _hybridTimeService.nextLogicalTime(),
    );

    final id = _typingRecordId(threadId, userId);
    if (activeDb == null) {
      if (activeRoom == null) return;
      await crdtService.put(
        activeRoom,
        id,
        state.toJson(),
        tableName: 'chat_messages',
      );
      return;
    }

    await activeDb
        .into(activeDb.chatMessages)
        .insertOnConflictUpdate(
          ChatMessageEntity(id: id, value: state.toJson(), isDeleted: 0),
        );
  }

  @override
  Stream<List<ChatUserPresence>> watchPresence({
    Duration activeThreshold = const Duration(minutes: 2),
  }) {
    final activeDb = db;
    final activeRoom = roomName;
    const pattern = 'presence:%';

    final Stream<List<dynamic>> source = activeDb == null
        ? (activeRoom == null
              ? Stream.value(const <dynamic>[])
              : crdtService.watch(
                  activeRoom,
                  "SELECT id, value FROM chat_messages WHERE is_deleted = 0 AND id LIKE '$pattern'",
                ))
        : (activeDb.select(activeDb.chatMessages)
                ..where((t) => t.isDeleted.equals(0))
                ..where((t) => t.id.like(pattern)))
              .watch();

    return source.map((rows) {
      final byUser = <String, ChatUserPresence>{};
      for (final row in rows) {
        final raw = activeDb == null
            ? (row['value'] as String? ?? '')
            : row.value;
        if (raw.isEmpty) continue;
        ChatUserPresence? presence;
        try {
          presence = ChatUserPresenceMapper.fromJson(raw);
        } catch (_) {
          presence = null;
        }
        if (presence == null) continue;

        final current = byUser[presence.userId];
        if (current == null ||
            presence.lastSeenAt.isAfter(current.lastSeenAt) ||
            presence.logicalTime > current.logicalTime) {
          byUser[presence.userId] = presence;
        }
      }

      final now = _hybridTimeService.getAdjustedTimeLocal();
      final list = byUser.values.map((presence) {
        final active = now.difference(presence.lastSeenAt) <= activeThreshold;
        if (active) return presence;
        return presence.copyWith(state: 'offline');
      }).toList();

      list.sort(
        (a, b) => a.userId.toLowerCase().compareTo(b.userId.toLowerCase()),
      );
      return list;
    });
  }

  @override
  Future<void> touchPresence({
    required String userId,
    required String state,
  }) async {
    if (userId.isEmpty || state.trim().isEmpty) return;
    final activeDb = db;
    final activeRoom = roomName;

    final presence = ChatUserPresence(
      userId: userId,
      state: state.trim(),
      lastSeenAt: _hybridTimeService.getAdjustedTimeLocal(),
      logicalTime: _hybridTimeService.nextLogicalTime(),
    );

    final id = '$_presenceIdPrefix${_encodeKeyPart(userId)}';
    if (activeDb == null) {
      if (activeRoom == null) return;
      await crdtService.put(
        activeRoom,
        id,
        presence.toJson(),
        tableName: 'chat_messages',
      );
      return;
    }

    await activeDb
        .into(activeDb.chatMessages)
        .insertOnConflictUpdate(
          ChatMessageEntity(id: id, value: presence.toJson(), isDeleted: 0),
        );
  }

  @override
  Stream<List<ChatModerationEvent>> watchModerationEvents({
    String? threadId,
    String? targetUserId,
  }) {
    final activeDb = db;
    final activeRoom = roomName;
    const pattern = 'mod:%';

    final Stream<List<dynamic>> source = activeDb == null
        ? (activeRoom == null
              ? Stream.value(const <dynamic>[])
              : crdtService.watch(
                  activeRoom,
                  "SELECT id, value FROM chat_messages WHERE is_deleted = 0 AND id LIKE '$pattern'",
                ))
        : (activeDb.select(activeDb.chatMessages)
                ..where((t) => t.isDeleted.equals(0))
                ..where((t) => t.id.like(pattern)))
              .watch();

    return source.map((rows) {
      final events = rows
          .map((row) {
            final raw = activeDb == null
                ? (row['value'] as String? ?? '')
                : row.value;
            if (raw.isEmpty) return null;
            try {
              return ChatModerationEventMapper.fromJson(raw);
            } catch (_) {
              return null;
            }
          })
          .whereType<ChatModerationEvent>()
          .where((event) => threadId == null || event.threadId == threadId)
          .where(
            (event) =>
                targetUserId == null || event.targetUserId == targetUserId,
          )
          .toList();

      events.sort((a, b) {
        final byTime = b.timestamp.compareTo(a.timestamp);
        if (byTime != 0) return byTime;
        return b.logicalTime.compareTo(a.logicalTime);
      });

      return events;
    });
  }

  @override
  Future<void> saveModerationEvent(ChatModerationEvent event) async {
    final activeDb = db;
    final activeRoom = roomName;
    final id = event.id.startsWith(_moderationIdPrefix)
        ? event.id
        : '$_moderationIdPrefix${event.id}';
    final normalized = event.copyWith(id: id);

    if (activeDb == null) {
      if (activeRoom == null) return;
      await crdtService.put(
        activeRoom,
        id,
        normalized.toJson(),
        tableName: 'chat_messages',
      );
      return;
    }

    await activeDb
        .into(activeDb.chatMessages)
        .insertOnConflictUpdate(
          ChatMessageEntity(id: id, value: normalized.toJson(), isDeleted: 0),
        );
  }

  @override
  Future<List<ChatSearchResult>> searchMessages(
    ChatSearchQuery query, {
    int limit = 100,
  }) async {
    final keyword = query.keyword.trim().toLowerCase();
    final allMessages = await _loadAllMessages();

    final filtered = allMessages.where((message) {
      if (message.isDeleted) return false;
      if (query.threadId != null &&
          query.threadId!.isNotEmpty &&
          message.threadId != query.threadId) {
        return false;
      }
      if (query.authorId != null &&
          query.authorId!.isNotEmpty &&
          message.senderId != query.authorId) {
        return false;
      }
      if (query.from != null && message.timestamp.isBefore(query.from!)) {
        return false;
      }
      if (query.to != null && message.timestamp.isAfter(query.to!)) {
        return false;
      }
      if (query.hasReply &&
          (message.replyToMessageId == null ||
              message.replyToMessageId!.isEmpty)) {
        return false;
      }
      if (query.hasMention &&
          !message.mentionsEveryone &&
          message.mentionUserIds.isEmpty &&
          message.mentionRoleIds.isEmpty) {
        return false;
      }
      if (keyword.isEmpty) return true;
      return message.content.toLowerCase().contains(keyword);
    }).toList();

    filtered.sort((a, b) {
      final byTime = b.timestamp.compareTo(a.timestamp);
      if (byTime != 0) return byTime;
      return b.logicalTime.compareTo(a.logicalTime);
    });

    return filtered
        .take(max(1, limit))
        .map(
          (message) => ChatSearchResult(
            message: message,
            snippet: _buildSnippet(message.content, keyword),
          ),
        )
        .toList();
  }

  @override
  Future<ChatThread> ensureDirectMessageThread({
    required String localUserId,
    required String peerUserId,
  }) async {
    final activeDb = db;
    final activeRoom = roomName;
    final threadId = _buildDmThreadId(localUserId, peerUserId);
    if (activeDb == null) {
      if (activeRoom != null) {
        final rows = await crdtService.query(
          activeRoom,
          'SELECT value FROM chat_threads WHERE id = ? AND is_deleted = 0',
          [threadId],
        );
        if (rows.isNotEmpty) {
          final value = rows.first['value'] as String? ?? '';
          if (value.isNotEmpty) {
            try {
              return ChatThreadMapper.fromJson(value);
            } catch (_) {}
          }
        }
      }
      final thread = ChatThread(
        id: threadId,
        kind: ChatThread.dmKind,
        name: 'Direct message',
        participantIds: [localUserId, peerUserId]..sort(),
        createdBy: localUserId,
        createdAt: _hybridTimeService.getAdjustedTimeLocal(),
        logicalTime: _hybridTimeService.nextLogicalTime(),
      );
      await saveChatThread(thread);
      return thread;
    }

    final row =
        await (activeDb.select(activeDb.chatThreads)
              ..where((t) => t.id.equals(threadId))
              ..where((t) => t.isDeleted.equals(0)))
            .getSingleOrNull();
    if (row != null) {
      return ChatThreadMapper.fromJson(row.value);
    }

    final members = [localUserId, peerUserId]..sort();
    final thread = ChatThread(
      id: threadId,
      kind: ChatThread.dmKind,
      name: 'Direct message',
      participantIds: members,
      createdBy: localUserId,
      createdAt: _hybridTimeService.getAdjustedTimeLocal(),
      logicalTime: _hybridTimeService.nextLogicalTime(),
    );
    await saveChatThread(thread);
    return thread;
  }

  List<ChatMessage> _deserializeAndSortMessages(
    List<({String id, String value})> rows, {
    required String? threadNeedle,
    required String? defaultNeedle,
  }) {
    final messages = rows
        .map((row) {
          if (!_isMessageId(row.id)) return null;
          final raw = row.value;
          if (threadNeedle != null &&
              !raw.contains(threadNeedle) &&
              (defaultNeedle == null || !raw.contains(defaultNeedle))) {
            return null;
          }
          try {
            return ChatMessageMapper.fromJson(raw);
          } catch (e) {
            Log.e('[ChatRepository]', 'Error decoding ChatMessage', e);
            return null;
          }
        })
        .whereType<ChatMessage>()
        .toList();

    messages.sort((a, b) {
      final byPhysical = a.timestamp.millisecondsSinceEpoch.compareTo(
        b.timestamp.millisecondsSinceEpoch,
      );
      if (byPhysical != 0) return byPhysical;
      return a.logicalTime.compareTo(b.logicalTime);
    });

    var moved = true;
    var safety = 0;
    while (moved && safety < messages.length * 2) {
      moved = false;
      safety += 1;
      final indexById = <String, int>{
        for (var i = 0; i < messages.length; i++) messages[i].id: i,
      };
      for (var i = 0; i < messages.length; i++) {
        final replyTo = messages[i].replyToMessageId;
        if (replyTo == null || replyTo.isEmpty) continue;
        final parentIndex = indexById[replyTo];
        if (parentIndex == null) continue;
        if (i < parentIndex) {
          final msg = messages.removeAt(i);
          final refreshedParentIndex = indexById[replyTo] ?? parentIndex;
          final insertAt = min(refreshedParentIndex + 1, messages.length);
          messages.insert(insertAt, msg);
          moved = true;
          break;
        }
      }
    }

    return messages;
  }

  List<ChatThread> _deserializeAndSortThreads(List<({String value})> rows) {
    final now = DateTime.now();
    final threads = rows
        .map((row) {
          if (row.value.isEmpty) return null;
          try {
            return ChatThreadMapper.fromJson(row.value);
          } catch (e) {
            Log.e('[ChatRepository]', 'Error decoding ChatThread', e);
            return null;
          }
        })
        .whereType<ChatThread>()
        .where(
          (thread) => !thread.isExpired || thread.id == ChatThread.generalId,
        )
        .toList();

    if (!threads.any((thread) => thread.id == ChatThread.generalId)) {
      threads.add(
        ChatThread(
          id: ChatThread.generalId,
          kind: ChatThread.channelKind,
          name: 'general',
          createdBy: '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    }

    threads.removeWhere(
      (thread) =>
          thread.expiresAt != null &&
          now.isAfter(thread.expiresAt!) &&
          thread.id != ChatThread.generalId,
    );

    threads.sort((a, b) {
      if (a.id == ChatThread.generalId) return -1;
      if (b.id == ChatThread.generalId) return 1;
      if (a.kind != b.kind) return _kindSortOrder(a.kind, b.kind);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return threads;
  }

  String _buildDmThreadId(String userA, String userB) {
    final members = [userA, userB]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return 'chat:dm:${Uri.encodeComponent(members[0])}:${Uri.encodeComponent(members[1])}';
  }

  int _kindSortOrder(String kindA, String kindB) {
    const order = <String, int>{
      ChatThread.channelKind: 0,
      ChatThread.subthreadKind: 1,
      ChatThread.dmKind: 2,
    };
    final a = order[kindA] ?? 99;
    final b = order[kindB] ?? 99;
    return a.compareTo(b);
  }

  String _typingRecordId(String threadId, String userId) {
    return '$_typingIdPrefix${_encodeKeyPart(threadId)}:${_encodeKeyPart(userId)}';
  }

  String _encodeKeyPart(String value) => base64Url.encode(utf8.encode(value));

  bool _isMessageId(String id) => id.startsWith(_messageIdPrefix);

  Future<List<ChatMessage>> _loadAllMessages() async {
    final activeDb = db;
    final activeRoom = roomName;
    if (activeDb == null) {
      if (activeRoom == null) return const <ChatMessage>[];
      final rows = await crdtService.query(
        activeRoom,
        "SELECT id, value FROM chat_messages WHERE is_deleted = 0 AND id LIKE '$_messageIdPrefix%'",
      );
      return _deserializeAndSortMessages(
        rows.map((row) {
          return (
            id: row['id'] as String? ?? '',
            value: row['value'] as String? ?? '',
          );
        }).toList(),
        threadNeedle: null,
        defaultNeedle: null,
      );
    }

    final rows =
        await (activeDb.select(activeDb.chatMessages)
              ..where((t) => t.isDeleted.equals(0))
              ..where((t) => t.id.like('$_messageIdPrefix%')))
            .get();

    return _deserializeAndSortMessages(
      rows.map((row) => (id: row.id, value: row.value)).toList(),
      threadNeedle: null,
      defaultNeedle: null,
    );
  }

  String _buildSnippet(String content, String keyword) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';

    if (keyword.isEmpty) {
      return trimmed.length <= 120
          ? trimmed
          : '${trimmed.substring(0, 120)}...';
    }

    final lower = trimmed.toLowerCase();
    final index = lower.indexOf(keyword);
    if (index < 0) {
      return trimmed.length <= 120
          ? trimmed
          : '${trimmed.substring(0, 120)}...';
    }

    final start = max(0, index - 28);
    final end = min(trimmed.length, index + keyword.length + 52);
    final prefix = start > 0 ? '...' : '';
    final suffix = end < trimmed.length ? '...' : '';
    return '$prefix${trimmed.substring(start, end)}$suffix';
  }

  Future<ChatThread?> _loadThreadById(String threadId) async {
    if (threadId.isEmpty) return null;
    final activeDb = db;
    final activeRoom = roomName;

    if (activeDb == null) {
      if (activeRoom == null) return null;
      final rows = await crdtService.query(
        activeRoom,
        'SELECT value FROM chat_threads WHERE id = ? AND is_deleted = 0',
        [threadId],
      );
      if (rows.isEmpty) return null;
      final value = rows.first['value'] as String? ?? '';
      if (value.isEmpty) return null;
      try {
        return ChatThreadMapper.fromJson(value);
      } catch (_) {
        return null;
      }
    }

    final row =
        await (activeDb.select(activeDb.chatThreads)
              ..where((t) => t.id.equals(threadId))
              ..where((t) => t.isDeleted.equals(0)))
            .getSingleOrNull();
    if (row == null) return null;

    try {
      return ChatThreadMapper.fromJson(row.value);
    } catch (_) {
      return null;
    }
  }

  Future<void> _touchThreadActivity(String threadId, DateTime at) async {
    final thread = await _loadThreadById(threadId);
    if (thread == null) return;
    final existing = thread.lastActivityAt;
    if (existing != null && !at.isAfter(existing)) return;
    await saveChatThread(thread.copyWith(lastActivityAt: at));
  }
}
