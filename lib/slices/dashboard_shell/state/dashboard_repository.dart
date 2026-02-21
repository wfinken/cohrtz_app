import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/di/app_providers.dart';
import '../../../shared/database/database.dart';
import '../../sync/runtime/crdt_service.dart';
import '../../sync/runtime/hybrid_time_service.dart';
import 'local_dashboard_storage.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import '../../../shared/utils/logging_service.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final currentRoomName = ref.watch(
    syncServiceProvider.select((s) => s.currentRoomName),
  );
  return DashboardRepository(
    ref.read(crdtServiceProvider),
    currentRoomName,
    ref.read(hybridTimeServiceProvider),
  );
});

class DashboardRepository {
  final CrdtService _crdtService;
  final String? _roomName;
  final HybridTimeService _hybridTimeService;

  DashboardRepository(
    this._crdtService,
    this._roomName,
    this._hybridTimeService,
  );

  AppDatabase? get _db =>
      _roomName != null ? _crdtService.getDatabase(_roomName) : null;

  String? get currentRoomName => _roomName;

  Stream<List<TaskItem>> watchTasks() {
    final db = _db;
    if (db == null) return Stream.value([]);
    return (db.select(
      db.tasks,
    )..where((t) => t.isDeleted.equals(0))).watch().map((rows) {
      return rows
          .map((row) {
            try {
              return TaskItemMapper.fromJson(row.value);
            } catch (e) {
              Log.e(
                '[DashboardRepository]',
                'Error decoding TaskItem: ${row.value}',
                e,
              );
              return null;
            }
          })
          .whereType<TaskItem>()
          .toList();
    });
  }

  Future<void> saveTask(TaskItem task) async {
    final db = _db;
    if (db == null) return;
    await db
        .into(db.tasks)
        .insertOnConflictUpdate(
          TaskEntity(
            id: task.id,
            value: jsonEncode(task.toMap()),
            isDeleted: 0,
          ),
        );
  }

  Future<void> deleteTask(String id) async {
    final db = _db;
    final roomName = _roomName;
    if (db == null || roomName == null) return;

    // Use CRDT delete for proper tombstoning and sync
    await _crdtService.delete(roomName, id, 'tasks');
  }

  Stream<List<CalendarEvent>> watchEvents() {
    final db = _db;
    if (db == null) return Stream.value([]);
    return (db.select(
      db.calendarEvents,
    )..where((t) => t.isDeleted.equals(0))).watch().map((rows) {
      return rows
          .map((row) {
            try {
              return CalendarEventMapper.fromJson(row.value);
            } catch (e) {
              Log.e('[DashboardRepository]', 'Error decoding CalendarEvent', e);
              return null;
            }
          })
          .whereType<CalendarEvent>()
          .toList();
    });
  }

  Future<void> saveEvent(CalendarEvent event) async {
    final db = _db;
    if (db == null) return;
    await db
        .into(db.calendarEvents)
        .insertOnConflictUpdate(
          CalendarEventEntity(
            id: event.id,
            value: jsonEncode(event.toMap()),
            isDeleted: 0,
          ),
        );
  }

  Future<void> deleteEvent(String id) async {
    final db = _db;
    final roomName = _roomName;
    if (db == null || roomName == null) return;

    // Use CRDT delete for proper tombstoning and sync
    await _crdtService.delete(roomName, id, 'calendar_events');
  }

  Stream<List<VaultItem>> watchVaultItems() {
    final db = _db;
    if (db == null) return Stream.value([]);
    return (db.select(
      db.vaultItems,
    )..where((t) => t.isDeleted.equals(0))).watch().map((rows) {
      return rows
          .map((row) {
            try {
              final jsonStr = row.value;
              return VaultItemMapper.fromJson(jsonStr);
            } catch (e) {
              Log.e('[DashboardRepository]', 'Error decoding VaultItem', e);
              return null;
            }
          })
          .whereType<VaultItem>()
          .toList();
    });
  }

  Future<void> saveVaultItem(VaultItem item) async {
    final db = _db;
    if (db == null) return;
    await db
        .into(db.vaultItems)
        .insertOnConflictUpdate(
          VaultItemEntity(
            id: item.id,
            value: jsonEncode(item.toMap()),
            isDeleted: 0,
          ),
        );
  }

  Future<void> deleteVaultItem(String id) async {
    final db = _db;
    final roomName = _roomName;
    if (db == null || roomName == null) return;

    // Use CRDT delete for proper tombstoning and sync
    await _crdtService.delete(roomName, id, 'vault_items');
  }

  Stream<List<ChatMessage>> watchMessages({String? threadId}) {
    final db = _db;
    if (db == null) return Stream.value([]);
    final threadNeedle = threadId == null ? null : '"threadId":"$threadId"';
    final defaultNeedle = threadId == ChatThread.generalId
        ? '"threadId":"${ChatMessage.defaultThreadId}"'
        : null;

    return (db.select(
      db.chatMessages,
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
              Log.e('[DashboardRepository]', 'Error decoding ChatMessage', e);
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

      // Causality guard: render replies after their parent when possible.
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

  Stream<List<ChatMessage>> watchMessagesForThread(String threadId) {
    return watchMessages(threadId: threadId);
  }

  Future<void> saveMessage(ChatMessage message) async {
    final db = _db;
    if (db == null) return;
    await db
        .into(db.chatMessages)
        .insertOnConflictUpdate(
          ChatMessageEntity(
            id: message.id,
            value: jsonEncode(message.toMap()),
            isDeleted: 0,
          ),
        );
  }

  Stream<List<ChatThread>> watchChatThreads() {
    final db = _db;
    if (db == null) return Stream.value(const <ChatThread>[]);
    return (db.select(
      db.chatThreads,
    )..where((t) => t.isDeleted.equals(0))).watch().map((rows) {
      final now = DateTime.now();
      final threads = rows
          .map((row) {
            try {
              final jsonStr = row.value;
              return ChatThreadMapper.fromJson(jsonStr);
            } catch (e) {
              Log.e('[DashboardRepository]', 'Error decoding ChatThread', e);
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

  Future<void> saveChatThread(ChatThread thread) async {
    final db = _db;
    if (db == null) return;
    await db
        .into(db.chatThreads)
        .insertOnConflictUpdate(
          ChatThreadEntity(
            id: thread.id,
            value: jsonEncode(thread.toMap()),
            isDeleted: 0,
          ),
        );
  }

  Future<void> deleteChatThread(String threadId) async {
    final db = _db;
    final roomName = _roomName;
    if (db == null || roomName == null) return;

    // Use CRDT delete for proper tombstoning and sync
    await _crdtService.delete(roomName, threadId, 'chat_threads');
  }

  Future<void> leaveDirectMessageThread({
    required String threadId,
    required String userId,
  }) async {
    final db = _db;
    if (db == null || userId.isEmpty) return;
    final row =
        await (db.select(db.chatThreads)
              ..where((t) => t.id.equals(threadId))
              ..where((t) => t.isDeleted.equals(0)))
            .getSingleOrNull();
    if (row == null) return;
    final raw = row.value;

    ChatThread thread;
    try {
      thread = ChatThreadMapper.fromJson(raw);
    } catch (_) {
      return;
    }

    if (!thread.isDm) return;
    if (!thread.participantIds.contains(userId)) return;

    final nextParticipants = thread.participantIds
        .where((id) => id != userId)
        .toList();
    if (nextParticipants.isEmpty) {
      await deleteChatThreadAndMessages(threadId);
      return;
    }

    await saveChatThread(thread.copyWith(participantIds: nextParticipants));
  }

  Future<void> deleteChatThreadAndMessages(String threadId) async {
    final db = _db;
    final roomName = _roomName;
    if (db == null || roomName == null) return;

    final rows = await db.select(db.chatMessages).get();

    for (final row in rows) {
      final value = row.value;
      if (value.isEmpty) continue;
      try {
        final message = ChatMessageMapper.fromJson(value);
        if (message.threadId != threadId) continue;
        // Use CRDT delete for proper tombstoning and sync
        await _crdtService.delete(roomName, row.id, 'chat_messages');
      } catch (_) {}
    }

    await deleteChatThread(threadId);
  }

  Future<void> clearChatMessages(String threadId) async {
    final db = _db;
    final roomName = _roomName;
    if (db == null || roomName == null) return;

    final rows = await db.select(db.chatMessages).get();

    for (final row in rows) {
      final value = row.value;
      if (value.isEmpty) continue;
      try {
        final message = ChatMessageMapper.fromJson(value);
        if (message.threadId != threadId) continue;
        // Use CRDT delete for proper tombstoning and sync
        await _crdtService.delete(roomName, row.id, 'chat_messages');
      } catch (_) {}
    }
  }

  Future<ChatThread> ensureDirectMessageThread({
    required String localUserId,
    required String peerUserId,
  }) async {
    final db = _db;
    if (db == null) {
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
        await (db.select(db.chatThreads)
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

  Stream<List<UserProfile>> watchUserProfiles() {
    final db = _db;
    if (db == null) {
      return Stream.value([]);
    }
    return (db.select(
      db.userProfiles,
    )..where((t) => t.isDeleted.equals(0))).watch().map((rows) {
      final profiles = rows
          .map((row) {
            try {
              final jsonStr = row.value;
              return UserProfileMapper.fromJson(jsonStr);
            } catch (_) {
              // Handle legacy double-encoded values
              try {
                final unwrapped = jsonDecode(row.value);
                if (unwrapped is String) {
                  return UserProfileMapper.fromJson(unwrapped);
                }
              } catch (e) {
                Log.e('[DashboardRepository]', 'Error decoding UserProfile', e);
              }
              return null;
            }
          })
          .whereType<UserProfile>()
          .toList();
      return profiles;
    });
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final db = _db;
    if (db == null) return;
    await db
        .into(db.userProfiles)
        .insertOnConflictUpdate(
          UserProfileEntity(
            id: profile.id,
            value: jsonEncode(profile.toMap()),
            isDeleted: 0,
          ),
        );
  }

  Future<void> deleteUserProfile(String id) async {
    final db = _db;
    final roomName = _roomName;
    if (db == null || roomName == null) return;

    // Use CRDT delete for proper tombstoning and sync
    await _crdtService.delete(roomName, id, 'user_profiles');
  }

  Stream<List<PollItem>> watchPolls() {
    final db = _db;
    if (db == null) return Stream.value([]);
    return (db.select(
      db.polls,
    )..where((t) => t.isDeleted.equals(0))).watch().map((rows) {
      return rows
          .map((row) {
            try {
              final jsonStr = row.value;
              return PollItemMapper.fromJson(jsonStr);
            } catch (e) {
              Log.e('[DashboardRepository]', 'Error decoding PollItem', e);
              return null;
            }
          })
          .whereType<PollItem>()
          .toList();
    });
  }

  Future<void> savePoll(PollItem poll) async {
    final db = _db;
    if (db == null) return;
    await db
        .into(db.polls)
        .insertOnConflictUpdate(
          PollEntity(
            id: poll.id,
            value: jsonEncode(poll.toMap()),
            isDeleted: 0,
          ),
        );
  }

  Future<void> deletePoll(String id) async {
    final db = _db;
    final roomName = _roomName;
    if (db == null || roomName == null) return;

    // Use CRDT delete for proper tombstoning and sync
    await _crdtService.delete(roomName, id, 'polls');
  }

  Stream<GroupSettings?> watchGroupSettings() {
    final db = _db;
    if (db == null) return Stream.value(null);
    return db.select(db.groupSettingsTable).watch().asyncMap((rows) async {
      if (rows.isEmpty) return null;

      final canonical = rows.where((r) => r.id == 'group_settings').toList();
      final legacys = rows.where((r) => r.id != 'group_settings').toList();

      if (legacys.isNotEmpty) {
        GroupSettings? targetSettings;
        if (canonical.isNotEmpty) {
          final jsonStr = canonical.first.value;
          try {
            targetSettings = GroupSettingsMapper.fromJson(jsonStr);
          } catch (e) {
            Log.e('[DashboardRepository]', 'Error decoding GroupSettings', e);
          }
        }

        for (final legacy in legacys) {
          try {
            final legacyJson = legacy.value;
            final legacySettings = GroupSettingsMapper.fromJson(legacyJson);

            if (targetSettings == null) {
              targetSettings = legacySettings.copyWith(id: 'group_settings');
            } else {
              final existingCodes = targetSettings.invites
                  .map((i) => i.code)
                  .toSet();
              final newInvites = legacySettings.invites.where(
                (i) => !existingCodes.contains(i.code),
              );

              if (newInvites.isNotEmpty) {
                targetSettings = targetSettings.copyWith(
                  invites: [...targetSettings.invites, ...newInvites],
                );
              }
            }

            // Use CRDT delete for legacy data cleanup
            if (_roomName != null) {
              await _crdtService.delete(_roomName, legacy.id, 'group_settings');
            }
          } catch (e) {
            debugPrint(
              '[DashboardRepository] Error migrating legacy settings: $e',
            );
          }
        }

        if (targetSettings != null) {
          await saveGroupSettings(targetSettings);
          return targetSettings;
        }
      }

      final record = rows.firstWhere(
        (r) => r.id == 'group_settings',
        orElse: () => rows.first,
      );
      final jsonStr = record.value;
      try {
        return GroupSettingsMapper.fromJson(jsonStr);
      } catch (e) {
        Log.e('[DashboardRepository]', 'Error decoding GroupSettings', e);
        return null;
      }
    });
  }

  Future<void> saveGroupSettings(GroupSettings settings) async {
    final db = _db;
    if (db == null) return;
    final safeSettings = settings.id != 'group_settings'
        ? settings.copyWith(id: 'group_settings')
        : settings;

    await db
        .into(db.groupSettingsTable)
        .insertOnConflictUpdate(
          GroupSettingsEntity(
            id: safeSettings.id,
            value: jsonEncode(safeSettings.toMap()),
            isDeleted: 0,
          ),
        );
  }

  Stream<List<DashboardWidget>> watchWidgets() {
    final db = _db;
    if (db == null) return Stream.value([]);
    return (db.select(
      db.dashboardWidgets,
    )..where((t) => t.isDeleted.equals(0))).watch().map((rows) {
      return rows
          .map((row) {
            try {
              final jsonStr = row.value;
              return DashboardWidgetMapper.fromJson(jsonStr);
            } catch (e) {
              Log.e(
                '[DashboardRepository]',
                'Error decoding DashboardWidget',
                e,
              );
              return null;
            }
          })
          .whereType<DashboardWidget>()
          .toList();
    });
  }

  Future<void> saveWidget(DashboardWidget widget) async {
    final db = _db;
    if (db == null) return;
    await db
        .into(db.dashboardWidgets)
        .insertOnConflictUpdate(
          DashboardWidgetEntity(
            id: widget.id,
            value: jsonEncode(widget.toMap()),
            isDeleted: 0,
          ),
        );
  }

  Future<void> deleteWidget(String id) async {
    final db = _db;
    final roomName = _roomName;
    if (db == null || roomName == null) return;

    // Use CRDT delete for proper tombstoning and sync
    await _crdtService.delete(roomName, id, 'dashboard_widgets');
  }
}

final userProfilesProvider = StreamProvider<List<UserProfile>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.watchUserProfiles();
});

final pollsStreamProvider = StreamProvider<List<PollItem>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.watchPolls();
});

final groupSettingsProvider = StreamProvider<GroupSettings?>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.watchGroupSettings();
});

final localDashboardStorageProvider = Provider(
  (ref) => LocalDashboardStorage(),
);

final dashboardWidgetsProvider = FutureProvider.autoDispose
    .family<
      ({List<DashboardWidget> widgets, bool requiresScaling}),
      ({String groupId, int? columns})
    >((ref, args) async {
      final storage = ref.watch(localDashboardStorageProvider);
      var widgets = await storage.loadWidgets(
        args.groupId,
        columns: args.columns,
      );

      bool requiresScaling = false;

      if (widgets.isEmpty) {
        // Try fallback to master
        if (args.columns != null && args.columns != 12) {
          final masterWidgets = await storage.loadWidgets(
            args.groupId,
            columns: 12,
          );
          if (masterWidgets.isNotEmpty) {
            return (widgets: masterWidgets, requiresScaling: true);
          }
        }

        // Inject defaults
        widgets = [
          DashboardWidget(
            id: 'calendar',
            type: 'calendar',
            x: 0,
            y: 0,
            width: 4,
            height: 1,
          ),
          DashboardWidget(
            id: 'vault',
            type: 'vault',
            x: 4,
            y: 0,
            width: 4,
            height: 1,
          ),
          DashboardWidget(
            id: 'tasks',
            type: 'tasks',
            x: 8,
            y: 0,
            width: 4,
            height: 1,
          ),
          DashboardWidget(
            id: 'notes',
            type: 'notes',
            x: 0,
            y: 1,
            width: 4,
            height: 1,
          ),
          DashboardWidget(
            id: 'polls',
            type: 'polls',
            x: 4,
            y: 1,
            width: 4,
            height: 1,
          ),
          DashboardWidget(
            id: 'users',
            type: 'users',
            x: 8,
            y: 1,
            width: 4,
            height: 1,
          ),
          DashboardWidget(
            id: 'chat',
            type: 'chat',
            x: 0,
            y: 2,
            width: 12,
            height: 1,
          ),
        ];

        if (args.columns != null && args.columns != 12) {
          requiresScaling = true;
        }
      }
      return (widgets: widgets, requiresScaling: requiresScaling);
    });
