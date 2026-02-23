import 'dart:convert';
import 'dart:math';

import 'package:cohortz/shared/database/database.dart';
import 'package:cohortz/shared/utils/logging_service.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/sync/runtime/hybrid_time_service.dart';

import 'room_repository_base.dart';

abstract class IChatRepository {
  Stream<List<ChatMessage>> watchMessages({String? threadId});
  Stream<List<ChatMessage>> watchMessagesForThread(String threadId);
  Future<void> saveMessage(ChatMessage message);
  Stream<List<ChatThread>> watchChatThreads();
  Future<void> saveChatThread(ChatThread thread);
  Future<void> deleteChatThread(String threadId);
  Future<void> leaveDirectMessageThread({
    required String threadId,
    required String userId,
  });
  Future<void> deleteChatThreadAndMessages(String threadId);
  Future<void> clearChatMessages(String threadId);
  Future<ChatThread> ensureDirectMessageThread({
    required String localUserId,
    required String peerUserId,
  });
}

class ChatRepository extends RoomRepositoryBase implements IChatRepository {
  final HybridTimeService _hybridTimeService;

  const ChatRepository(
    super.crdtService,
    super.roomName,
    this._hybridTimeService,
  );

  @override
  Stream<List<ChatMessage>> watchMessages({String? threadId}) {
    final activeDb = db;
    if (activeDb == null) return Stream.value([]);
    final threadNeedle = threadId == null ? null : '"threadId":"$threadId"';
    final defaultNeedle = threadId == ChatThread.generalId
        ? '"threadId":"${ChatMessage.defaultThreadId}"'
        : null;

    return (activeDb.select(
      activeDb.chatMessages,
    )..where((t) => t.isDeleted.equals(0))).watch().map((rows) {
      final messages = rows
          .map((row) {
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
    });
  }

  @override
  Stream<List<ChatMessage>> watchMessagesForThread(String threadId) {
    return watchMessages(threadId: threadId);
  }

  @override
  Future<void> saveMessage(ChatMessage message) async {
    final activeDb = db;
    if (activeDb == null) return;
    await activeDb
        .into(activeDb.chatMessages)
        .insertOnConflictUpdate(
          ChatMessageEntity(
            id: message.id,
            value: jsonEncode(message.toMap()),
            isDeleted: 0,
          ),
        );
  }

  @override
  Stream<List<ChatThread>> watchChatThreads() {
    final activeDb = db;
    if (activeDb == null) return Stream.value(const <ChatThread>[]);
    return (activeDb.select(
      activeDb.chatThreads,
    )..where((t) => t.isDeleted.equals(0))).watch().map((rows) {
      final now = DateTime.now();
      final threads = rows
          .map((row) {
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
        if (a.kind != b.kind) {
          return a.kind == ChatThread.channelKind ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return threads;
    });
  }

  @override
  Future<void> saveChatThread(ChatThread thread) async {
    final activeDb = db;
    if (activeDb == null) return;
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
  Future<void> leaveDirectMessageThread({
    required String threadId,
    required String userId,
  }) async {
    final activeDb = db;
    if (activeDb == null || userId.isEmpty) return;
    final row =
        await (activeDb.select(activeDb.chatThreads)
              ..where((t) => t.id.equals(threadId))
              ..where((t) => t.isDeleted.equals(0)))
            .getSingleOrNull();
    if (row == null) return;

    ChatThread thread;
    try {
      thread = ChatThreadMapper.fromJson(row.value);
    } catch (_) {
      return;
    }

    if (!thread.isDm || !thread.participantIds.contains(userId)) return;

    final nextParticipants = thread.participantIds
        .where((id) => id != userId)
        .toList();
    if (nextParticipants.isEmpty) {
      await deleteChatThreadAndMessages(threadId);
      return;
    }
    await saveChatThread(thread.copyWith(participantIds: nextParticipants));
  }

  @override
  Future<void> deleteChatThreadAndMessages(String threadId) async {
    final activeDb = db;
    if (activeDb == null || roomName == null) return;

    final rows = await activeDb.select(activeDb.chatMessages).get();
    for (final row in rows) {
      final value = row.value;
      if (value.isEmpty) continue;
      try {
        final message = ChatMessageMapper.fromJson(value);
        if (message.threadId != threadId) continue;
        await crdtDelete(row.id, 'chat_messages');
      } catch (_) {}
    }

    await deleteChatThread(threadId);
  }

  @override
  Future<void> clearChatMessages(String threadId) async {
    final activeDb = db;
    if (activeDb == null || roomName == null) return;

    final rows = await activeDb.select(activeDb.chatMessages).get();
    for (final row in rows) {
      final value = row.value;
      if (value.isEmpty) continue;
      try {
        final message = ChatMessageMapper.fromJson(value);
        if (message.threadId != threadId) continue;
        await crdtDelete(row.id, 'chat_messages');
      } catch (_) {}
    }
  }

  @override
  Future<ChatThread> ensureDirectMessageThread({
    required String localUserId,
    required String peerUserId,
  }) async {
    final activeDb = db;
    if (activeDb == null) {
      return ChatThread(
        id: _buildDmThreadId(localUserId, peerUserId),
        kind: ChatThread.dmKind,
        name: 'Direct message',
        participantIds: [localUserId, peerUserId]..sort(),
        createdBy: localUserId,
        createdAt: _hybridTimeService.getAdjustedTimeLocal(),
        logicalTime: _hybridTimeService.nextLogicalTime(),
      );
    }

    final threadId = _buildDmThreadId(localUserId, peerUserId);
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

  String _buildDmThreadId(String userA, String userB) {
    final members = [userA, userB]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return 'chat:dm:${Uri.encodeComponent(members[0])}:${Uri.encodeComponent(members[1])}';
  }
}
