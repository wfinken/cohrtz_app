import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/di/app_providers.dart';
import '../../../shared/database/database.dart';
import '../../sync/runtime/crdt_service.dart';
import '../../sync/runtime/hybrid_time_service.dart';
import 'local_dashboard_storage.dart';
import 'repositories/calendar_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/task_repository.dart';
import 'repositories/vault_repository.dart';
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

final taskRepositoryProvider = Provider<ITaskRepository>((ref) {
  return _DashboardTaskRepositoryAdapter(
    ref.watch(dashboardRepositoryProvider),
  );
});

final calendarRepositoryProvider = Provider<ICalendarRepository>((ref) {
  return _DashboardCalendarRepositoryAdapter(
    ref.watch(dashboardRepositoryProvider),
  );
});

final vaultRepositoryProvider = Provider<IVaultRepository>((ref) {
  return _DashboardVaultRepositoryAdapter(
    ref.watch(dashboardRepositoryProvider),
  );
});

final chatRepositoryProvider = Provider<IChatRepository>((ref) {
  return _DashboardChatRepositoryAdapter(
    ref.watch(dashboardRepositoryProvider),
  );
});

class _DashboardTaskRepositoryAdapter implements ITaskRepository {
  final DashboardRepository _repository;
  const _DashboardTaskRepositoryAdapter(this._repository);

  @override
  Stream<List<TaskItem>> watchTasks() => _repository.watchTasks();

  @override
  Future<void> saveTask(TaskItem task) => _repository.saveTask(task);

  @override
  Future<void> deleteTask(String id) => _repository.deleteTask(id);
}

class _DashboardCalendarRepositoryAdapter implements ICalendarRepository {
  final DashboardRepository _repository;
  const _DashboardCalendarRepositoryAdapter(this._repository);

  @override
  Stream<List<CalendarEvent>> watchEvents() => _repository.watchEvents();

  @override
  Future<void> saveEvent(CalendarEvent event) => _repository.saveEvent(event);

  @override
  Future<void> deleteEvent(String id) => _repository.deleteEvent(id);
}

class _DashboardVaultRepositoryAdapter implements IVaultRepository {
  final DashboardRepository _repository;
  const _DashboardVaultRepositoryAdapter(this._repository);

  @override
  Stream<List<VaultItem>> watchVaultItems() => _repository.watchVaultItems();

  @override
  Future<void> saveVaultItem(VaultItem item) => _repository.saveVaultItem(item);

  @override
  Future<void> deleteVaultItem(String id) => _repository.deleteVaultItem(id);
}

class _DashboardChatRepositoryAdapter implements IChatRepository {
  final DashboardRepository _repository;
  const _DashboardChatRepositoryAdapter(this._repository);

  @override
  Stream<List<ChatMessage>> watchMessages({String? threadId}) =>
      _repository.watchMessages(threadId: threadId);

  @override
  Stream<List<ChatMessage>> watchMessagesForThread(String threadId) =>
      _repository.watchMessagesForThread(threadId);

  @override
  Future<void> saveMessage(ChatMessage message) =>
      _repository.saveMessage(message);

  @override
  Stream<List<ChatThread>> watchChatThreads() => _repository.watchChatThreads();

  @override
  Future<void> saveChatThread(ChatThread thread) =>
      _repository.saveChatThread(thread);

  @override
  Future<void> deleteChatThread(String threadId) =>
      _repository.deleteChatThread(threadId);

  @override
  Future<void> leaveDirectMessageThread({
    required String threadId,
    required String userId,
  }) =>
      _repository.leaveDirectMessageThread(threadId: threadId, userId: userId);

  @override
  Future<void> deleteChatThreadAndMessages(String threadId) =>
      _repository.deleteChatThreadAndMessages(threadId);

  @override
  Future<void> clearChatMessages(String threadId) =>
      _repository.clearChatMessages(threadId);

  @override
  Future<ChatThread> ensureDirectMessageThread({
    required String localUserId,
    required String peerUserId,
  }) => _repository.ensureDirectMessageThread(
    localUserId: localUserId,
    peerUserId: peerUserId,
  );
}

class DashboardRepository {
  final CrdtService _crdtService;
  final String? _roomName;
  late final TaskRepository _taskRepository;
  late final CalendarRepository _calendarRepository;
  late final VaultRepository _vaultRepository;
  late final ChatRepository _chatRepository;

  DashboardRepository(
    this._crdtService,
    this._roomName,
    HybridTimeService hybridTimeService,
  ) {
    _taskRepository = TaskRepository(_crdtService, _roomName);
    _calendarRepository = CalendarRepository(_crdtService, _roomName);
    _vaultRepository = VaultRepository(_crdtService, _roomName);
    _chatRepository = ChatRepository(
      _crdtService,
      _roomName,
      hybridTimeService,
    );
  }

  AppDatabase? get _db =>
      _roomName != null ? _crdtService.getDatabase(_roomName) : null;

  String? get currentRoomName => _roomName;
  ITaskRepository get tasks => _taskRepository;
  ICalendarRepository get calendar => _calendarRepository;
  IVaultRepository get vault => _vaultRepository;
  IChatRepository get chat => _chatRepository;

  Stream<List<TaskItem>> watchTasks() => _taskRepository.watchTasks();
  Future<void> saveTask(TaskItem task) => _taskRepository.saveTask(task);
  Future<void> deleteTask(String id) => _taskRepository.deleteTask(id);

  Stream<List<CalendarEvent>> watchEvents() =>
      _calendarRepository.watchEvents();
  Future<void> saveEvent(CalendarEvent event) =>
      _calendarRepository.saveEvent(event);
  Future<void> deleteEvent(String id) => _calendarRepository.deleteEvent(id);

  Stream<List<VaultItem>> watchVaultItems() =>
      _vaultRepository.watchVaultItems();
  Future<void> saveVaultItem(VaultItem item) =>
      _vaultRepository.saveVaultItem(item);
  Future<void> deleteVaultItem(String id) =>
      _vaultRepository.deleteVaultItem(id);

  Stream<List<ChatMessage>> watchMessages({String? threadId}) =>
      _chatRepository.watchMessages(threadId: threadId);
  Stream<List<ChatMessage>> watchMessagesForThread(String threadId) =>
      _chatRepository.watchMessagesForThread(threadId);
  Future<void> saveMessage(ChatMessage message) =>
      _chatRepository.saveMessage(message);
  Stream<List<ChatThread>> watchChatThreads() =>
      _chatRepository.watchChatThreads();
  Future<void> saveChatThread(ChatThread thread) =>
      _chatRepository.saveChatThread(thread);
  Future<void> deleteChatThread(String threadId) =>
      _chatRepository.deleteChatThread(threadId);
  Future<void> leaveDirectMessageThread({
    required String threadId,
    required String userId,
  }) => _chatRepository.leaveDirectMessageThread(
    threadId: threadId,
    userId: userId,
  );
  Future<void> deleteChatThreadAndMessages(String threadId) =>
      _chatRepository.deleteChatThreadAndMessages(threadId);
  Future<void> clearChatMessages(String threadId) =>
      _chatRepository.clearChatMessages(threadId);
  Future<ChatThread> ensureDirectMessageThread({
    required String localUserId,
    required String peerUserId,
  }) => _chatRepository.ensureDirectMessageThread(
    localUserId: localUserId,
    peerUserId: peerUserId,
  );

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
