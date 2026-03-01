import 'package:cohortz/slices/calendar/models/calendar_event.dart';
import 'package:cohortz/slices/chat/models/chat_message.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/notes/models/note_model.dart';
import 'package:cohortz/slices/permissions_feature/models/member_model.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';
import 'package:cohortz/slices/polls/models/poll_item.dart';
import 'package:cohortz/slices/tasks/models/task_item.dart';
import 'package:cohortz/app/di/app_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../helpers/e2e_env_config.dart';
import '../helpers/eventual_assert.dart';
import '../helpers/two_client_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const config = E2eEnvConfig.fromEnvironment;

  if (config.shouldSkip) {
    // ignore: avoid_print
    print(
      'Skipping two_client_smoke_test.dart: ${config.skipReason}. '
      'Run with ${E2eEnvConfig.runCommand}.',
    );
  }

  testWidgets(
    'syncs core and extended data across configured clients',
    (tester) async {
      expect(
        config.userCount,
        greaterThanOrEqualTo(2),
        reason: 'COHRTZ_E2E_USER_COUNT must be >= 2 for sync coverage.',
      );

      final harness = await TwoClientHarness.start(config);
      addTearDown(harness.dispose);

      final clients = harness.clients;
      expect(clients, hasLength(config.userCount));

      await _runTaskCrud(clients);
      await _runEventCrud(clients);
      await _runNoteCrud(clients);
      await _runChatCrud(clients);

      await _runPollCrud(clients);
      await _runGroupSettingsSync(clients);
      await _runRoleCrud(clients);
      await _runMemberCrud(clients);
    },
    skip: config.shouldSkip,
  );
}

Future<void> _runTaskCrud(List<E2eClientContext> clients) async {
  final creator = clients.first;
  final updater = clients[1];
  final taskId = _uniqueId('task');

  final created = TaskItem(
    id: taskId,
    title: 'smoke task created by A',
    assignedTo: 'Both',
    creatorId: creator.identity,
  );
  await creator.dashboard.saveTask(created);

  await expectEventually(
    description: 'all clients should receive created task $taskId',
    condition: () async {
      return _allClients(clients, (client) async {
        final tasks = await client.dashboard.watchTasks().first;
        return tasks.any(
          (task) => task.id == taskId && task.title == created.title,
        );
      });
    },
  );

  final updated = TaskItem(
    id: taskId,
    title: 'smoke task updated by B',
    assignedTo: 'Both',
    creatorId: creator.identity,
    isCompleted: true,
    completedBy: updater.identity,
  );
  await updater.dashboard.saveTask(updated);
  await _forceSyncPulse(clients);
  // Re-apply once to mitigate rare CRDT clock races where the first update
  // can lose to an earlier writer's timestamp.
  await updater.dashboard.saveTask(updated);
  await _forceSyncPulse(clients);

  await expectEventually(
    description: 'all clients should receive updated task $taskId',
    condition: () async {
      final mismatches = <String>[];
      for (final client in clients) {
        final tasks = await client.dashboard.watchTasks().first;
        final matching = tasks.where((task) => task.id == taskId).toList();
        if (matching.isEmpty) {
          mismatches.add('${client.label}:missing');
          continue;
        }
        final converged = matching.any(
          (task) =>
              task.title == updated.title &&
              task.isCompleted &&
              _sameIdentity(task.completedBy, updater.identity),
        );
        if (!converged) {
          final snapshot = matching.first;
          mismatches.add(
            '${client.label}:title=${snapshot.title},completed=${snapshot.isCompleted},completedBy=${snapshot.completedBy}',
          );
        }
      }
      if (mismatches.isNotEmpty) {
        throw StateError(
          'Task $taskId not converged across clients: ${mismatches.join(' | ')}',
        );
      }
      return true;
    },
  );

  await creator.dashboard.deleteTask(taskId);

  await expectEventually(
    description: 'task $taskId should be deleted on all clients',
    condition: () async {
      return _allClients(clients, (client) async {
        final tasks = await client.dashboard.watchTasks().first;
        return !tasks.any((task) => task.id == taskId);
      });
    },
  );
}

Future<void> _runEventCrud(List<E2eClientContext> clients) async {
  final creator = clients.first;
  final updater = clients[1];
  final eventId = _uniqueId('event');
  final start = DateTime.now().toUtc().add(const Duration(minutes: 5));

  final created = CalendarEvent(
    id: eventId,
    title: 'smoke event created by A',
    time: start,
    endTime: start.add(const Duration(hours: 1)),
    location: 'Room A',
    creatorId: creator.identity,
  );
  await creator.dashboard.saveEvent(created);

  await expectEventually(
    description: 'all clients should receive created event $eventId',
    condition: () async {
      return _allClients(clients, (client) async {
        final events = await client.dashboard.watchEvents().first;
        return events.any(
          (event) => event.id == eventId && event.title == created.title,
        );
      });
    },
  );

  final updated = CalendarEvent(
    id: eventId,
    title: 'smoke event updated by B',
    time: start.add(const Duration(minutes: 10)),
    endTime: start.add(const Duration(hours: 2)),
    location: 'Room B',
    description: 'updated from clientB',
    creatorId: creator.identity,
  );
  await updater.dashboard.saveEvent(updated);

  await expectEventually(
    description: 'all clients should receive updated event $eventId',
    condition: () async {
      return _allClients(clients, (client) async {
        final events = await client.dashboard.watchEvents().first;
        return events.any(
          (event) =>
              event.id == eventId &&
              event.title == updated.title &&
              event.location == updated.location,
        );
      });
    },
  );

  await creator.dashboard.deleteEvent(eventId);

  await expectEventually(
    description: 'event $eventId should be deleted on all clients',
    condition: () async {
      return _allClients(clients, (client) async {
        final events = await client.dashboard.watchEvents().first;
        return !events.any((event) => event.id == eventId);
      });
    },
  );
}

Future<void> _runNoteCrud(List<E2eClientContext> clients) async {
  final creator = clients.first;
  final updater = clients[1];
  final noteId = _uniqueId('note');
  final now = DateTime.now().toUtc();

  final created = Note(
    id: noteId,
    title: 'smoke note created by A',
    content: 'initial content from clientA',
    updatedBy: creator.identity,
    updatedAt: now,
    logicalTime: 1,
  );
  await creator.notes.saveNote(created);

  await expectEventually(
    description: 'all clients should receive created note $noteId',
    condition: () async {
      return _allClients(clients, (client) async {
        final notes = await client.notes.watchNotes().first;
        return notes.any(
          (note) => note.id == noteId && note.title == created.title,
        );
      });
    },
  );

  final updated = Note(
    id: noteId,
    title: 'smoke note updated by B',
    content: 'updated content from clientB',
    updatedBy: updater.identity,
    updatedAt: now.add(const Duration(minutes: 1)),
    logicalTime: 2,
  );
  await updater.notes.saveNote(updated);

  await expectEventually(
    description: 'all clients should receive updated note $noteId',
    condition: () async {
      return _allClients(clients, (client) async {
        final notes = await client.notes.watchNotes().first;
        return notes.any(
          (note) =>
              note.id == noteId &&
              note.title == updated.title &&
              note.content == updated.content,
        );
      });
    },
  );

  await creator.notes.deleteNote(noteId);

  await expectEventually(
    description: 'note $noteId should be deleted on all clients',
    condition: () async {
      return _allClients(clients, (client) async {
        final notes = await client.notes.watchNotes().first;
        return !notes.any((note) => note.id == noteId);
      });
    },
  );
}

Future<void> _runChatCrud(List<E2eClientContext> clients) async {
  final creator = clients.first;
  final updater = clients[1];
  final threadId = _uniqueId('thread');
  final messageId = _uniqueId('message');
  final createdAt = DateTime.now().toUtc();

  final thread = ChatThread(
    id: threadId,
    kind: ChatThread.channelKind,
    name: 'smoke-thread',
    participantIds: clients
        .map((client) => client.identity)
        .toList(growable: false),
    createdBy: creator.identity,
    createdAt: createdAt,
    logicalTime: 1,
  );
  await creator.dashboard.saveChatThread(thread);

  await expectEventually(
    description: 'all clients should receive created thread $threadId',
    condition: () async {
      return _allClients(clients, (client) async {
        final threads = await client.dashboard.watchChatThreads().first;
        return threads.any((value) => value.id == threadId);
      });
    },
  );

  final createdMessage = ChatMessage(
    id: messageId,
    senderId: creator.identity,
    threadId: threadId,
    content: 'hello from clientA',
    timestamp: createdAt,
    logicalTime: 1,
  );
  await creator.dashboard.saveMessage(createdMessage);

  await expectEventually(
    description: 'all clients should receive created chat message $messageId',
    condition: () async {
      return _allClients(clients, (client) async {
        final messages = await client.dashboard
            .watchMessagesForThread(threadId)
            .first;
        return messages.any(
          (message) =>
              message.id == messageId &&
              message.content == createdMessage.content,
        );
      });
    },
  );

  final updatedMessage = ChatMessage(
    id: messageId,
    senderId: creator.identity,
    threadId: threadId,
    content: 'hello updated by clientB',
    timestamp: createdAt.add(const Duration(seconds: 10)),
    logicalTime: 2,
  );
  await updater.dashboard.saveMessage(updatedMessage);

  await expectEventually(
    description: 'all clients should receive updated chat message $messageId',
    condition: () async {
      return _allClients(clients, (client) async {
        final messages = await client.dashboard
            .watchMessagesForThread(threadId)
            .first;
        return messages.any(
          (message) =>
              message.id == messageId &&
              message.content == updatedMessage.content,
        );
      });
    },
  );

  await creator.dashboard.deleteChatThreadAndMessages(threadId);

  await expectEventually(
    description:
        'thread $threadId and message $messageId should be deleted on all clients',
    condition: () async {
      return _allClients(clients, (client) async {
        final threads = await client.dashboard.watchChatThreads().first;
        final messages = await client.dashboard
            .watchMessagesForThread(threadId)
            .first;

        final threadExists = threads.any((thread) => thread.id == threadId);
        final msgExists = messages.any((message) => message.id == messageId);

        return !threadExists && !msgExists;
      });
    },
  );
}

Future<void> _runPollCrud(List<E2eClientContext> clients) async {
  final creator = clients.first;
  final updater = clients[1];
  final pollId = _uniqueId('poll');
  final endTime = DateTime.now().toUtc().add(const Duration(hours: 2));

  final created = PollItem(
    id: pollId,
    question: 'smoke poll created by A',
    approvedCount: 0,
    rejectedCount: 0,
    requiredVotes: clients.length,
    endTime: endTime,
    pendingVoters: const <PendingVoter>[],
    creatorId: creator.identity,
  );
  await creator.dashboard.savePoll(created);

  await expectEventually(
    description: 'all clients should receive created poll $pollId',
    condition: () async {
      return _allClients(clients, (client) async {
        final polls = await client.dashboard.watchPolls().first;
        return polls.any(
          (poll) => poll.id == pollId && poll.question == created.question,
        );
      });
    },
  );

  final updated = PollItem(
    id: pollId,
    question: 'smoke poll updated by B',
    approvedCount: 1,
    rejectedCount: 0,
    requiredVotes: clients.length,
    endTime: endTime,
    pendingVoters: const <PendingVoter>[],
    creatorId: creator.identity,
    votedUserIds: [updater.identity],
  );
  await updater.dashboard.savePoll(updated);

  await expectEventually(
    description: 'all clients should receive updated poll $pollId',
    condition: () async {
      return _allClients(clients, (client) async {
        final polls = await client.dashboard.watchPolls().first;
        return polls.any(
          (poll) =>
              poll.id == pollId &&
              poll.question == updated.question &&
              poll.approvedCount == 1,
        );
      });
    },
  );

  await creator.dashboard.deletePoll(pollId);

  await expectEventually(
    description: 'poll $pollId should be deleted on all clients',
    condition: () async {
      return _allClients(clients, (client) async {
        final polls = await client.dashboard.watchPolls().first;
        return !polls.any((poll) => poll.id == pollId);
      });
    },
  );
}

Future<void> _runGroupSettingsSync(List<E2eClientContext> clients) async {
  final creator = clients.first;
  final updater = clients[1];
  final createdAt = DateTime.now().toUtc();

  final created = GroupSettings(
    id: 'group_settings',
    name: 'smoke-group-a',
    createdAt: createdAt,
    logicalTime: 1,
    groupType: GroupType.team,
    dataRoomName: creator.room,
    ownerId: creator.identity,
  );
  await creator.dashboard.saveGroupSettings(created);

  await expectEventually(
    description: 'all clients should receive group settings from clientA',
    condition: () async {
      return _allClients(clients, (client) async {
        final settings = await client.dashboard.watchGroupSettings().first;
        return settings != null &&
            settings.id == 'group_settings' &&
            settings.name == created.name;
      });
    },
  );

  final updated = GroupSettings(
    id: 'group_settings',
    name: 'smoke-group-b',
    createdAt: createdAt,
    logicalTime: 2,
    groupType: GroupType.guild,
    dataRoomName: creator.room,
    ownerId: creator.identity,
  );
  await updater.dashboard.saveGroupSettings(updated);

  await expectEventually(
    description:
        'all clients should receive updated group settings from clientB',
    condition: () async {
      return _allClients(clients, (client) async {
        final settings = await client.dashboard.watchGroupSettings().first;
        return settings != null &&
            settings.id == 'group_settings' &&
            settings.name == updated.name &&
            settings.groupType == GroupType.guild;
      });
    },
  );
}

Future<void> _runRoleCrud(List<E2eClientContext> clients) async {
  final creator = clients.first;
  final updater = clients[1];
  final roleId = _uniqueId('role');

  final created = Role(
    id: roleId,
    groupId: creator.room,
    name: 'smoke-role-a',
    color: 0xFF2A9D8F,
    position: 1,
    permissions: 0,
  );
  await creator.roles.saveRole(created);

  await expectEventually(
    description: 'all clients should receive role $roleId',
    condition: () async {
      return _allClients(clients, (client) async {
        final roles = await client.roles.watchRoles().first;
        return roles.any(
          (role) => role.id == roleId && role.name == created.name,
        );
      });
    },
  );

  final updated = Role(
    id: roleId,
    groupId: creator.room,
    name: 'smoke-role-b',
    color: 0xFFE76F51,
    position: 2,
    permissions: 4,
    isHoisted: true,
  );
  await updater.roles.saveRole(updated);

  await expectEventually(
    description: 'all clients should receive updated role $roleId',
    condition: () async {
      return _allClients(clients, (client) async {
        final roles = await client.roles.watchRoles().first;
        return roles.any(
          (role) =>
              role.id == roleId && role.name == updated.name && role.isHoisted,
        );
      });
    },
  );

  await creator.roles.deleteRole(roleId);

  await expectEventually(
    description: 'role $roleId should be deleted on all clients',
    condition: () async {
      return _allClients(clients, (client) async {
        final roles = await client.roles.watchRoles().first;
        return !roles.any((role) => role.id == roleId);
      });
    },
  );
}

Future<void> _runMemberCrud(List<E2eClientContext> clients) async {
  final creator = clients.first;
  final updater = clients[1];
  final memberId = _uniqueId('member');

  final created = GroupMember(id: memberId, roleIds: const <String>[]);
  await creator.members.saveMember(created);

  await expectEventually(
    description: 'all clients should receive member $memberId',
    condition: () async {
      return _allClients(clients, (client) async {
        final members = await client.members.watchMembers().first;
        return members.any((member) => member.id == memberId);
      });
    },
  );

  final updated = GroupMember(
    id: memberId,
    roleIds: const <String>['role-alpha', 'role-beta'],
  );
  await updater.members.saveMember(updated);

  await expectEventually(
    description: 'all clients should receive updated member $memberId',
    condition: () async {
      return _allClients(clients, (client) async {
        final members = await client.members.watchMembers().first;
        return members.any(
          (member) => member.id == memberId && member.roleIds.length == 2,
        );
      });
    },
  );

  await creator.members.deleteMember(memberId);

  await expectEventually(
    description: 'member $memberId should be deleted on all clients',
    condition: () async {
      return _allClients(clients, (client) async {
        final members = await client.members.watchMembers().first;
        return !members.any((member) => member.id == memberId);
      });
    },
  );
}

Future<bool> _allClients(
  List<E2eClientContext> clients,
  Future<bool> Function(E2eClientContext client) predicate,
) async {
  final results = await Future.wait<bool>(clients.map(predicate));
  return results.every((value) => value);
}

bool _sameIdentity(String a, String b) {
  String normalize(String value) {
    final trimmed = value.trim().toLowerCase();
    return trimmed.startsWith('user:') ? trimmed.substring(5) : trimmed;
  }

  return normalize(a) == normalize(b);
}

Future<void> _forceSyncPulse(List<E2eClientContext> clients) async {
  if (clients.isEmpty) return;
  final room = clients.first.room;

  await Future.wait(
    clients.map((client) async {
      final handshake = client.container.read(handshakeHandlerProvider);
      final syncProtocol = client.container.read(syncProtocolProvider);
      final broadcaster = client.container.read(dataBroadcasterProvider);

      await handshake.requestHandshake(room, force: true);
      await syncProtocol.requestSync(room, force: true);
      await broadcaster.retryPendingUnicast(room);
      await broadcaster.retryBufferedPackets(room);
    }),
  );
}

String _uniqueId(String prefix) {
  return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}
