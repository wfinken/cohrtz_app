import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/notifications/activity_notification_orchestrator.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';

import 'notification_provider.dart';
import 'sync_service_provider.dart';
import 'identity_provider.dart';
import 'widget_notification_preferences_provider.dart';

import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';

void _bootstrapActivityNotifications(Ref ref) {
  final notificationService = ref.read(notificationServiceProvider);
  final syncService = ref.read(syncServiceProvider);
  final identityService = ref.read(identityServiceProvider);
  final widgetPrefs = ref.read(widgetNotificationPreferencesProvider);

  void log(String message) {}

  StreamSubscription<List<TaskItem>>? taskSubscription;
  StreamSubscription<List<CalendarEvent>>? eventSubscription;
  StreamSubscription<List<VaultItem>>? vaultSubscription;
  StreamSubscription<List<ChatMessage>>? chatSubscription;
  StreamSubscription<List<ChatThread>>? chatThreadSubscription;
  StreamSubscription<List<PollItem>>? pollSubscription;
  StreamSubscription<List<UserProfile>>? userSubscription;
  Timer? pollExpiryTimer;

  String? activeRoomName;

  bool tasksPrimed = false;
  bool eventsPrimed = false;
  bool vaultPrimed = false;
  bool chatsPrimed = false;
  bool pollsPrimed = false;
  bool usersPrimed = false;

  Set<String> knownTaskIds = {};
  Map<String, bool> knownTaskCompletionById = {};
  Set<String> knownEventIds = {};
  Set<String> knownVaultIds = {};
  Set<String> knownChatIds = {};
  Map<String, ChatThread> knownChatThreadsById = {};
  Set<String> knownPollIds = {};
  Map<String, PollItem> knownPollById = {};
  Map<String, String> knownPollStateById = {};
  final Set<String> pollRestartInFlight = {};
  Set<String> knownUserIds = {};
  Map<String, String> knownUserDisplayNames = {};
  GroupNotificationSettings notificationSettings =
      const GroupNotificationSettings();

  String currentIdentity() {
    return syncService.identity ?? identityService.profile?.id ?? '';
  }

  void updateNotificationSettings(GroupSettings? settings) {
    final userId = currentIdentity();
    notificationSettings =
        settings?.settingsForUser(userId) ?? const GroupNotificationSettings();
    log(
      'notification settings updated: '
      'tasks(new=${notificationSettings.newTasks}, done=${notificationSettings.completedTasks}) '
      'calendar=${notificationSettings.calendarEvents} '
      'vault=${notificationSettings.vaultItems} '
      'chat=${notificationSettings.chatMessages} '
      'polls(new=${notificationSettings.newPolls}, closed=${notificationSettings.closedPolls}, votes=${notificationSettings.pollVotes}) '
      'members(join=${notificationSettings.memberJoined}, left=${notificationSettings.memberLeft})',
    );
  }

  String roomDisplayName() {
    final room = activeRoomName;
    if (room == null || room.isEmpty) return 'Group';
    return syncService.getFriendlyName(room);
  }

  bool canRestartPoll(PollItem poll) {
    final myId = currentIdentity();
    return myId.isNotEmpty && poll.creatorId == myId;
  }

  Future<bool> restartPollIfNeeded(
    PollItem poll,
    DateTime now, {
    required String source,
  }) async {
    if (!poll.shouldRestartOnTieAt(now) || !canRestartPoll(poll)) {
      return false;
    }
    if (pollRestartInFlight.contains(poll.id)) return true;
    pollRestartInFlight.add(poll.id);
    try {
      await ref.read(dashboardRepositoryProvider).savePoll(poll.restart(now));
      log('revote restart triggered from $source for poll ${poll.id}.');
      return true;
    } finally {
      pollRestartInFlight.remove(poll.id);
    }
  }

  Future<void> handleTaskUpdate(List<TaskItem> tasks) async {
    final nextIds = tasks.map((task) => task.id).toSet();
    log(
      'tasks stream update: total=${nextIds.length}, known=${knownTaskIds.length}',
    );
    if (!tasksPrimed) {
      tasksPrimed = true;
      knownTaskIds = nextIds;
      knownTaskCompletionById = {
        for (final task in tasks) task.id: task.isCompleted,
      };
      log('tasks stream primed with ${nextIds.length} records.');
      return;
    }

    final localUserId = currentIdentity();
    final addedList = tasks
        .where((task) => !knownTaskIds.contains(task.id))
        .where((task) => task.creatorId != localUserId)
        .toList();
    final completedList = tasks
        .where((task) => knownTaskCompletionById[task.id] == false)
        .where((task) => task.isCompleted)
        .where((task) => task.completedBy != localUserId)
        .toList();
    knownTaskIds = nextIds;
    knownTaskCompletionById = {
      for (final task in tasks) task.id: task.isCompleted,
    };
    log('tasks stream delta: added=${addedList.length}');
    log('tasks completion delta: completed=${completedList.length}');

    final room = activeRoomName;
    if (room == null || room.isEmpty) return;
    final displayRoom = roomDisplayName();
    if (addedList.isNotEmpty) {
      log('detected ${addedList.length} new task(s) in "$displayRoom".');
    }
    if (completedList.isNotEmpty) {
      log(
        'detected ${completedList.length} completed task(s) in "$displayRoom".',
      );
    }

    final notifyNewTasks =
        notificationSettings.allNotifications && notificationSettings.newTasks;
    final notifyCompletedTasks =
        notificationSettings.allNotifications &&
        notificationSettings.completedTasks;

    final shouldCheckWidgetToggle =
        (notifyNewTasks && addedList.isNotEmpty) ||
        (notifyCompletedTasks && completedList.isNotEmpty);

    final widgetEnabled = shouldCheckWidgetToggle
        ? await widgetPrefs.isEnabled(groupId: room, widgetType: 'tasks')
        : true;

    if (widgetEnabled && notifyNewTasks) {
      for (final task in addedList) {
        unawaited(
          notificationService.showNewTask(
            roomName: displayRoom,
            title: task.title,
            assignedTo: task.assignedTo,
          ),
        );
      }
    }

    if (widgetEnabled && notifyCompletedTasks) {
      for (final task in completedList) {
        unawaited(
          notificationService.showTaskCompleted(
            roomName: displayRoom,
            title: task.title,
          ),
        );
      }
    }
  }

  Future<void> handleEventUpdate(List<CalendarEvent> events) async {
    final nextIds = events.map((event) => event.id).toSet();
    log(
      'events stream update: total=${nextIds.length}, known=${knownEventIds.length}',
    );
    if (!eventsPrimed) {
      eventsPrimed = true;
      knownEventIds = nextIds;
      log('events stream primed with ${nextIds.length} records.');
      return;
    }

    final localUserId = currentIdentity();
    final addedList = events
        .where((event) => !knownEventIds.contains(event.id))
        .where((event) => event.creatorId != localUserId)
        .toList();
    knownEventIds = nextIds;
    log('events stream delta: added=${addedList.length}');

    final room = activeRoomName;
    if (room == null || room.isEmpty) return;
    final displayRoom = roomDisplayName();
    if (addedList.isNotEmpty) {
      log(
        'detected ${addedList.length} new calendar event(s) in "$displayRoom".',
      );
    }

    final notifyEvents =
        notificationSettings.allNotifications &&
        notificationSettings.calendarEvents &&
        addedList.isNotEmpty;
    final widgetEnabled = notifyEvents
        ? await widgetPrefs.isEnabled(groupId: room, widgetType: 'calendar')
        : true;

    if (widgetEnabled && notifyEvents) {
      for (final event in addedList) {
        unawaited(
          notificationService.showNewCalendarEvent(
            roomName: displayRoom,
            title: event.title,
            location: event.location,
          ),
        );
      }
    }
  }

  Future<void> handleVaultUpdate(List<VaultItem> vaultItems) async {
    final nextIds = vaultItems.map((item) => item.id).toSet();
    log(
      'vault stream update: total=${nextIds.length}, known=${knownVaultIds.length}',
    );
    if (!vaultPrimed) {
      vaultPrimed = true;
      knownVaultIds = nextIds;
      log('vault stream primed with ${nextIds.length} records.');
      return;
    }

    final localUserId = currentIdentity();
    final addedList = vaultItems
        .where((item) => !knownVaultIds.contains(item.id))
        .where((item) => item.creatorId != localUserId)
        .toList();
    knownVaultIds = nextIds;
    log('vault stream delta: added=${addedList.length}');

    final room = activeRoomName;
    if (room == null || room.isEmpty) return;
    final displayRoom = roomDisplayName();
    if (addedList.isNotEmpty) {
      log('detected ${addedList.length} new vault item(s) in "$displayRoom".');
    }

    final notifyVault =
        notificationSettings.allNotifications &&
        notificationSettings.vaultItems &&
        addedList.isNotEmpty;
    final widgetEnabled = notifyVault
        ? await widgetPrefs.isEnabled(groupId: room, widgetType: 'vault')
        : true;

    if (widgetEnabled && notifyVault) {
      for (final item in addedList) {
        unawaited(
          notificationService.showNewVaultItem(
            roomName: displayRoom,
            label: item.label,
            type: item.type,
          ),
        );
      }
    }
  }

  String pollStateForNotification(PollItem poll, DateTime now) {
    final totalVotes = poll.approvedCount + poll.rejectedCount;
    final outcome = poll.outcomeAt(now);
    if (outcome == PollOutcomeState.active) return 'active';
    if (outcome == PollOutcomeState.approved) return 'passed';

    final failedByVotes =
        poll.requiredVotes > 0 && totalVotes >= poll.requiredVotes;
    if (failedByVotes) return 'failed';
    return 'expired';
  }

  String pollStatusLabel(String state) {
    switch (state) {
      case 'passed':
        return 'Passed';
      case 'failed':
        return 'Failed';
      case 'expired':
        return 'Expired';
      default:
        return 'Updated';
    }
  }

  Future<void> checkPollExpirations() async {
    final room = activeRoomName;
    if (room == null || room.isEmpty || knownPollById.isEmpty) return;

    final now = DateTime.now();
    final displayRoom = roomDisplayName();
    final transitions = <({PollItem poll, String state})>[];

    for (final poll in knownPollById.values) {
      final restarted = await restartPollIfNeeded(poll, now, source: 'timer');
      if (restarted) {
        knownPollStateById[poll.id] = 'active';
        continue;
      }
      final previousState = knownPollStateById[poll.id] ?? 'active';
      final nextState = pollStateForNotification(poll, now);
      if (previousState == 'active' && nextState == 'expired') {
        transitions.add((poll: poll, state: nextState));
      }
      knownPollStateById[poll.id] = nextState;
    }

    if (transitions.isNotEmpty) {
      log(
        'poll timer detected ${transitions.length} expired poll(s) in "$displayRoom".',
      );
    }

    final notifyPollTransitions =
        notificationSettings.allNotifications &&
        notificationSettings.closedPolls &&
        transitions.isNotEmpty;
    final widgetEnabled = notifyPollTransitions
        ? await widgetPrefs.isEnabled(groupId: room, widgetType: 'polls')
        : true;

    if (widgetEnabled && notifyPollTransitions) {
      for (final transition in transitions) {
        unawaited(
          notificationService.showPollClosed(
            roomName: displayRoom,
            question: transition.poll.question,
            status: pollStatusLabel(transition.state),
          ),
        );
      }
    }
  }

  void startPollExpiryTimer() {
    pollExpiryTimer?.cancel();
    pollExpiryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(checkPollExpirations());
    });
    unawaited(checkPollExpirations());
    log('poll expiry timer started.');
  }

  Future<void> handlePollUpdate(List<PollItem> polls) async {
    final nextIds = polls.map((poll) => poll.id).toSet();
    log(
      'polls stream update: total=${nextIds.length}, known=${knownPollIds.length}',
    );

    final now = DateTime.now();
    if (!pollsPrimed) {
      pollsPrimed = true;
      knownPollIds = nextIds;
      knownPollById = {for (final poll in polls) poll.id: poll};
      knownPollStateById = {
        for (final poll in polls) poll.id: pollStateForNotification(poll, now),
      };
      log('polls stream primed with ${nextIds.length} records.');
      return;
    }

    final localUserId = currentIdentity();
    final addedList = polls
        .where((poll) => !knownPollIds.contains(poll.id))
        .where((poll) => poll.creatorId != localUserId)
        .toList();
    final addedIds = addedList.map((poll) => poll.id).toSet();
    final closedTransitions = <({PollItem poll, String state})>[];
    final voteUpdates = <PollItem>[];

    for (final poll in polls) {
      final restarted = await restartPollIfNeeded(poll, now, source: 'stream');
      if (restarted) {
        continue;
      }
      if (addedIds.contains(poll.id)) {
        continue;
      }
      final previousPoll = knownPollById[poll.id];
      if (previousPoll != null && poll.totalVotes > previousPoll.totalVotes) {
        // Only notify if the new vote is NOT from the local user
        final newVoters = poll.votedUserIds.toSet().difference(
          previousPoll.votedUserIds.toSet(),
        );
        if (!newVoters.contains(localUserId)) {
          voteUpdates.add(poll);
        }
      }
      final previousState = knownPollStateById[poll.id] ?? 'active';
      final nextState = pollStateForNotification(poll, now);
      if (previousState == 'active' && nextState != 'active') {
        closedTransitions.add((poll: poll, state: nextState));
      }
    }

    knownPollIds = nextIds;
    knownPollById = {for (final poll in polls) poll.id: poll};
    knownPollStateById = {
      for (final poll in polls) poll.id: pollStateForNotification(poll, now),
    };

    log(
      'polls stream delta: added=${addedList.length}, votes=${voteUpdates.length}, closed=${closedTransitions.length}',
    );

    final room = activeRoomName;
    if (room == null || room.isEmpty) return;
    final displayRoom = roomDisplayName();
    if (addedList.isNotEmpty) {
      log('detected ${addedList.length} new poll(s) in "$displayRoom".');
    }
    if (closedTransitions.isNotEmpty) {
      log(
        'detected ${closedTransitions.length} closed poll(s) in "$displayRoom".',
      );
    }
    if (voteUpdates.isNotEmpty) {
      log('detected ${voteUpdates.length} vote update(s) in "$displayRoom".');
    }

    final notifyNewPolls =
        notificationSettings.allNotifications &&
        notificationSettings.newPolls &&
        addedList.isNotEmpty;
    final notifyClosedPolls =
        notificationSettings.allNotifications &&
        notificationSettings.closedPolls &&
        closedTransitions.isNotEmpty;
    final notifyPollVotes =
        notificationSettings.allNotifications &&
        notificationSettings.pollVotes &&
        voteUpdates.isNotEmpty;
    final shouldCheckWidgetToggle =
        notifyNewPolls || notifyClosedPolls || notifyPollVotes;
    final widgetEnabled = shouldCheckWidgetToggle
        ? await widgetPrefs.isEnabled(groupId: room, widgetType: 'polls')
        : true;

    if (widgetEnabled && notifyNewPolls) {
      for (final poll in addedList) {
        unawaited(
          notificationService.showNewPoll(
            roomName: displayRoom,
            question: poll.question,
          ),
        );
      }
    }

    if (widgetEnabled && notifyClosedPolls) {
      for (final transition in closedTransitions) {
        unawaited(
          notificationService.showPollClosed(
            roomName: displayRoom,
            question: transition.poll.question,
            status: pollStatusLabel(transition.state),
          ),
        );
      }
    }

    if (widgetEnabled && notifyPollVotes) {
      for (final poll in voteUpdates) {
        unawaited(
          notificationService.showPollVoteUpdate(
            roomName: displayRoom,
            question: poll.question,
            totalVotes: poll.totalVotes,
            memberCount: poll.requiredVotes,
          ),
        );
      }
    }
  }

  Future<void> handleUserUpdate(List<UserProfile> profiles) async {
    final nextIds = profiles.map((profile) => profile.id).toSet();
    log(
      'users stream update: total=${nextIds.length}, known=${knownUserIds.length}',
    );
    final nextNames = <String, String>{
      for (final profile in profiles) profile.id: profile.displayName,
    };

    if (!usersPrimed) {
      usersPrimed = true;
      knownUserIds = nextIds;
      knownUserDisplayNames = nextNames;
      log('users stream primed with ${nextIds.length} records.');
      return;
    }

    final localUserId = identityService.profile?.id ?? syncService.identity;
    final addedIds = nextIds
        .difference(knownUserIds)
        .where((id) => id != localUserId);
    final removedIds = knownUserIds
        .difference(nextIds)
        .where((id) => id != localUserId);
    final addedIdsList = addedIds.toList();
    final removedIdsList = removedIds.toList();
    log(
      'users stream delta: added=${addedIdsList.length}, removed=${removedIdsList.length}',
    );

    final room = activeRoomName;
    if (room != null && room.isNotEmpty) {
      final displayRoom = roomDisplayName();
      if (addedIdsList.isNotEmpty) {
        log(
          'detected ${addedIdsList.length} joined member(s) in "$displayRoom".',
        );
      }
      if (removedIdsList.isNotEmpty) {
        log(
          'detected ${removedIdsList.length} departed member(s) in "$displayRoom".',
        );
      }

      final notifyJoined =
          notificationSettings.allNotifications &&
          notificationSettings.memberJoined &&
          addedIdsList.isNotEmpty;
      final notifyLeft =
          notificationSettings.allNotifications &&
          notificationSettings.memberLeft &&
          removedIdsList.isNotEmpty;

      final shouldCheckWidgetToggle = notifyJoined || notifyLeft;
      final widgetEnabled = shouldCheckWidgetToggle
          ? await widgetPrefs.isEnabled(groupId: room, widgetType: 'users')
          : true;

      if (widgetEnabled && notifyJoined) {
        for (final userId in addedIdsList) {
          final name = nextNames[userId];
          unawaited(
            notificationService.showUserJoined(
              roomName: displayRoom,
              displayName: name == null || name.isEmpty
                  ? 'A member'
                  : name.trim(),
            ),
          );
        }
      }

      if (widgetEnabled && notifyLeft) {
        for (final userId in removedIdsList) {
          final previousName = knownUserDisplayNames[userId];
          unawaited(
            notificationService.showUserLeft(
              roomName: displayRoom,
              displayName: previousName == null || previousName.isEmpty
                  ? 'A member'
                  : previousName.trim(),
            ),
          );
        }
      }
    }

    knownUserIds = nextIds;
    knownUserDisplayNames = nextNames;
  }

  String previewMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return 'New message';
    if (trimmed.length <= 80) return trimmed;
    return '${trimmed.substring(0, 80)}...';
  }

  String chatNameForNotification(ChatMessage message, String? localUserId) {
    final thread = knownChatThreadsById[message.threadId];
    if (thread == null) {
      if (message.threadId == ChatThread.generalId ||
          message.threadId == ChatMessage.defaultThreadId) {
        return '#general';
      }
      return 'Chat';
    }

    if (thread.isDm) {
      var counterpartId = '';
      if (localUserId != null && localUserId.isNotEmpty) {
        counterpartId = thread.participantIds.firstWhere(
          (id) => id != localUserId,
          orElse: () => '',
        );
      }
      if (counterpartId.isEmpty && thread.participantIds.isNotEmpty) {
        counterpartId = thread.participantIds.first;
      }
      final counterpartName = knownUserDisplayNames[counterpartId]?.trim();
      if (counterpartName != null && counterpartName.isNotEmpty) {
        return 'DM: $counterpartName';
      }
      return 'Direct Message';
    }

    final normalized = thread.name.trim().replaceFirst(RegExp(r'^#+\s*'), '');
    if (normalized.isEmpty) return '#general';
    return '#$normalized';
  }

  Future<void> handleChatThreadUpdate(List<ChatThread> threads) async {
    knownChatThreadsById = {for (final thread in threads) thread.id: thread};
  }

  Future<void> handleChatUpdate(List<ChatMessage> messages) async {
    final nextIds = messages.map((message) => message.id).toSet();
    log(
      'chat stream update: total=${nextIds.length}, known=${knownChatIds.length}',
    );
    if (!chatsPrimed) {
      chatsPrimed = true;
      knownChatIds = nextIds;
      log('chat stream primed with ${nextIds.length} records.');
      return;
    }

    final addedList = messages
        .where((message) => !knownChatIds.contains(message.id))
        .toList();
    knownChatIds = nextIds;
    log('chat stream delta: added=${addedList.length}');

    final room = activeRoomName;
    if (room == null || room.isEmpty) return;

    final localUserId =
        ref.read(identityServiceProvider).profile?.id ??
        ref.read(syncServiceProvider).identity;
    final displayRoom = roomDisplayName();
    if (addedList.isNotEmpty) {
      log(
        'detected ${addedList.length} new chat message(s) in "$displayRoom".',
      );
    }

    if (notificationSettings.allNotifications &&
        notificationSettings.chatMessages) {
      final widgetEnabled = addedList.isNotEmpty
          ? await widgetPrefs.isEnabled(groupId: room, widgetType: 'chat')
          : true;
      if (!widgetEnabled) return;

      for (final message in addedList) {
        if (message.senderId == localUserId) {
          log(
            'skipping chat notification for local sender ${message.senderId}.',
          );
          continue;
        }
        final senderName = knownUserDisplayNames[message.senderId];
        unawaited(
          notificationService.showNewChatMessage(
            groupName: displayRoom,
            chatName: chatNameForNotification(message, localUserId),
            senderName: senderName == null || senderName.isEmpty
                ? 'Member'
                : senderName.trim(),
            messagePreview: previewMessage(message.content),
          ),
        );
      }
    }
  }

  Future<void> cancelSubscriptions() async {
    log('cancelling notification stream subscriptions.');
    await taskSubscription?.cancel();
    await eventSubscription?.cancel();
    await vaultSubscription?.cancel();
    await chatSubscription?.cancel();
    await chatThreadSubscription?.cancel();
    await pollSubscription?.cancel();
    await userSubscription?.cancel();
    pollExpiryTimer?.cancel();
    taskSubscription = null;
    eventSubscription = null;
    vaultSubscription = null;
    chatSubscription = null;
    chatThreadSubscription = null;
    pollSubscription = null;
    userSubscription = null;
    pollExpiryTimer = null;
  }

  void resetSnapshots() {
    log('resetting stream snapshots.');
    tasksPrimed = false;
    eventsPrimed = false;
    vaultPrimed = false;
    chatsPrimed = false;
    pollsPrimed = false;
    usersPrimed = false;
    knownTaskIds = {};
    knownTaskCompletionById = {};
    knownEventIds = {};
    knownVaultIds = {};
    knownChatIds = {};
    knownChatThreadsById = {};
    knownPollIds = {};
    knownPollById = {};
    knownPollStateById = {};
    knownUserIds = {};
    knownUserDisplayNames = {};
  }

  Future<void> rebindForRepository(DashboardRepository repository) async {
    log('rebinding notification streams.');
    await cancelSubscriptions();
    resetSnapshots();
    activeRoomName = repository.currentRoomName;
    log('active room set to: "${activeRoomName ?? ''}".');

    if (activeRoomName == null || activeRoomName!.isEmpty) {
      log('skipping subscriptions because no active room.');
      return;
    }

    taskSubscription = repository.watchTasks().listen(
      (tasks) => unawaited(handleTaskUpdate(tasks)),
    );
    eventSubscription = repository.watchEvents().listen(
      (events) => unawaited(handleEventUpdate(events)),
    );
    vaultSubscription = repository.watchVaultItems().listen(
      (vaultItems) => unawaited(handleVaultUpdate(vaultItems)),
    );
    chatSubscription = repository.watchMessages().listen(
      (messages) => unawaited(handleChatUpdate(messages)),
    );
    chatThreadSubscription = repository.watchChatThreads().listen(
      (threads) => unawaited(handleChatThreadUpdate(threads)),
    );
    pollSubscription = repository.watchPolls().listen(
      (polls) => unawaited(handlePollUpdate(polls)),
    );
    userSubscription = repository.watchUserProfiles().listen(
      (profiles) => unawaited(handleUserUpdate(profiles)),
    );
    startPollExpiryTimer();
    log('subscriptions attached for room "${roomDisplayName()}".');
  }

  log('bootstrap provider initialized.');
  updateNotificationSettings(ref.read(groupSettingsProvider).value);
  unawaited(notificationService.initialize());
  unawaited(rebindForRepository(ref.read(dashboardRepositoryProvider)));

  ref.listen<DashboardRepository>(dashboardRepositoryProvider, (_, nextRepo) {
    log('dashboard repository changed; rebinding.');
    unawaited(rebindForRepository(nextRepo));
  });

  ref.listen<AsyncValue<GroupSettings?>>(groupSettingsProvider, (_, next) {
    updateNotificationSettings(next.value);
  });

  ref.onDispose(() {
    log('bootstrap provider disposed.');
    unawaited(cancelSubscriptions());
  });
}

final activityNotificationOrchestratorProvider =
    Provider<ActivityNotificationOrchestrator>((ref) {
      return const ActivityNotificationOrchestrator(
        _bootstrapActivityNotifications,
      );
    });

final activityNotificationBootstrapProvider = Provider<void>((ref) {
  ref.read(activityNotificationOrchestratorProvider).bootstrap(ref);
});
