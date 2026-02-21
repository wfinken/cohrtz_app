import 'package:cohortz/slices/calendar/models/calendar_event.dart';
import 'package:cohortz/slices/chat/models/chat_message.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/notes/models/note_model.dart';
import 'package:cohortz/slices/permissions_feature/models/member_model.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';
import 'package:cohortz/slices/polls/models/poll_item.dart';
import 'package:cohortz/slices/tasks/models/task_item.dart';
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

  testWidgets('syncs core and extended data between two clients', (
    tester,
  ) async {
    expect(
      config.hasDistinctIdentities,
      isTrue,
      reason: 'COHRTZ_E2E_IDENTITY_A and COHRTZ_E2E_IDENTITY_B must differ.',
    );

    final harness = await TwoClientHarness.start(config);
    addTearDown(harness.dispose);

    final clientA = harness.clientA;
    final clientB = harness.clientB;

    await _runTaskCrud(clientA, clientB);
    await _runEventCrud(clientA, clientB);
    await _runNoteCrud(clientA, clientB);
    await _runChatCrud(clientA, clientB);

    await _runPollCrud(clientA, clientB);
    await _runGroupSettingsSync(clientA, clientB);
    await _runRoleCrud(clientA, clientB);
    await _runMemberCrud(clientA, clientB);
  }, skip: config.shouldSkip);
}

Future<void> _runTaskCrud(
  E2eClientContext clientA,
  E2eClientContext clientB,
) async {
  final taskId = _uniqueId('task');

  final created = TaskItem(
    id: taskId,
    title: 'smoke task created by A',
    assignedTo: 'Both',
    creatorId: clientA.identity,
  );
  await clientA.dashboard.saveTask(created);

  await expectEventually(
    description: 'clientB should receive created task $taskId',
    condition: () async {
      final tasks = await clientB.dashboard.watchTasks().first;
      return tasks.any(
        (task) => task.id == taskId && task.title == created.title,
      );
    },
  );

  final updated = TaskItem(
    id: taskId,
    title: 'smoke task updated by B',
    assignedTo: 'Both',
    creatorId: clientA.identity,
    isCompleted: true,
    completedBy: clientB.identity,
  );
  await clientB.dashboard.saveTask(updated);

  await expectEventually(
    description: 'clientA should receive updated task $taskId',
    condition: () async {
      final tasks = await clientA.dashboard.watchTasks().first;
      return tasks.any(
        (task) =>
            task.id == taskId &&
            task.title == updated.title &&
            task.isCompleted &&
            task.completedBy == clientB.identity,
      );
    },
  );

  await clientA.dashboard.deleteTask(taskId);

  await expectEventually(
    description: 'task $taskId should be deleted on both clients',
    condition: () async {
      final tasksA = await clientA.dashboard.watchTasks().first;
      final tasksB = await clientB.dashboard.watchTasks().first;
      final existsA = tasksA.any((task) => task.id == taskId);
      final existsB = tasksB.any((task) => task.id == taskId);
      return !existsA && !existsB;
    },
  );
}

Future<void> _runEventCrud(
  E2eClientContext clientA,
  E2eClientContext clientB,
) async {
  final eventId = _uniqueId('event');
  final start = DateTime.now().toUtc().add(const Duration(minutes: 5));

  final created = CalendarEvent(
    id: eventId,
    title: 'smoke event created by A',
    time: start,
    endTime: start.add(const Duration(hours: 1)),
    location: 'Room A',
    creatorId: clientA.identity,
  );
  await clientA.dashboard.saveEvent(created);

  await expectEventually(
    description: 'clientB should receive created event $eventId',
    condition: () async {
      final events = await clientB.dashboard.watchEvents().first;
      return events.any(
        (event) => event.id == eventId && event.title == created.title,
      );
    },
  );

  final updated = CalendarEvent(
    id: eventId,
    title: 'smoke event updated by B',
    time: start.add(const Duration(minutes: 10)),
    endTime: start.add(const Duration(hours: 2)),
    location: 'Room B',
    description: 'updated from clientB',
    creatorId: clientA.identity,
  );
  await clientB.dashboard.saveEvent(updated);

  await expectEventually(
    description: 'clientA should receive updated event $eventId',
    condition: () async {
      final events = await clientA.dashboard.watchEvents().first;
      return events.any(
        (event) =>
            event.id == eventId &&
            event.title == updated.title &&
            event.location == updated.location,
      );
    },
  );

  await clientA.dashboard.deleteEvent(eventId);

  await expectEventually(
    description: 'event $eventId should be deleted on both clients',
    condition: () async {
      final eventsA = await clientA.dashboard.watchEvents().first;
      final eventsB = await clientB.dashboard.watchEvents().first;
      final existsA = eventsA.any((event) => event.id == eventId);
      final existsB = eventsB.any((event) => event.id == eventId);
      return !existsA && !existsB;
    },
  );
}

Future<void> _runNoteCrud(
  E2eClientContext clientA,
  E2eClientContext clientB,
) async {
  final noteId = _uniqueId('note');
  final now = DateTime.now().toUtc();

  final created = Note(
    id: noteId,
    title: 'smoke note created by A',
    content: 'initial content from clientA',
    updatedBy: clientA.identity,
    updatedAt: now,
    logicalTime: 1,
  );
  await clientA.notes.saveNote(created);

  await expectEventually(
    description: 'clientB should receive created note $noteId',
    condition: () async {
      final notes = await clientB.notes.watchNotes().first;
      return notes.any(
        (note) => note.id == noteId && note.title == created.title,
      );
    },
  );

  final updated = Note(
    id: noteId,
    title: 'smoke note updated by B',
    content: 'updated content from clientB',
    updatedBy: clientB.identity,
    updatedAt: now.add(const Duration(minutes: 1)),
    logicalTime: 2,
  );
  await clientB.notes.saveNote(updated);

  await expectEventually(
    description: 'clientA should receive updated note $noteId',
    condition: () async {
      final notes = await clientA.notes.watchNotes().first;
      return notes.any(
        (note) =>
            note.id == noteId &&
            note.title == updated.title &&
            note.content == updated.content,
      );
    },
  );

  await clientA.notes.deleteNote(noteId);

  await expectEventually(
    description: 'note $noteId should be deleted on both clients',
    condition: () async {
      final notesA = await clientA.notes.watchNotes().first;
      final notesB = await clientB.notes.watchNotes().first;
      final existsA = notesA.any((note) => note.id == noteId);
      final existsB = notesB.any((note) => note.id == noteId);
      return !existsA && !existsB;
    },
  );
}

Future<void> _runChatCrud(
  E2eClientContext clientA,
  E2eClientContext clientB,
) async {
  final threadId = _uniqueId('thread');
  final messageId = _uniqueId('message');
  final createdAt = DateTime.now().toUtc();

  final thread = ChatThread(
    id: threadId,
    kind: ChatThread.channelKind,
    name: 'smoke-thread',
    participantIds: [clientA.identity, clientB.identity],
    createdBy: clientA.identity,
    createdAt: createdAt,
    logicalTime: 1,
  );
  await clientA.dashboard.saveChatThread(thread);

  await expectEventually(
    description: 'clientB should receive created thread $threadId',
    condition: () async {
      final threads = await clientB.dashboard.watchChatThreads().first;
      return threads.any((value) => value.id == threadId);
    },
  );

  final createdMessage = ChatMessage(
    id: messageId,
    senderId: clientA.identity,
    threadId: threadId,
    content: 'hello from clientA',
    timestamp: createdAt,
    logicalTime: 1,
  );
  await clientA.dashboard.saveMessage(createdMessage);

  await expectEventually(
    description: 'clientB should receive created chat message $messageId',
    condition: () async {
      final messages = await clientB.dashboard
          .watchMessagesForThread(threadId)
          .first;
      return messages.any(
        (message) =>
            message.id == messageId &&
            message.content == createdMessage.content,
      );
    },
  );

  final updatedMessage = ChatMessage(
    id: messageId,
    senderId: clientA.identity,
    threadId: threadId,
    content: 'hello updated by clientB',
    timestamp: createdAt.add(const Duration(seconds: 10)),
    logicalTime: 2,
  );
  await clientB.dashboard.saveMessage(updatedMessage);

  await expectEventually(
    description: 'clientA should receive updated chat message $messageId',
    condition: () async {
      final messages = await clientA.dashboard
          .watchMessagesForThread(threadId)
          .first;
      return messages.any(
        (message) =>
            message.id == messageId &&
            message.content == updatedMessage.content,
      );
    },
  );

  await clientA.dashboard.deleteChatThreadAndMessages(threadId);

  await expectEventually(
    description:
        'thread $threadId and message $messageId should be deleted on both clients',
    condition: () async {
      final threadsA = await clientA.dashboard.watchChatThreads().first;
      final threadsB = await clientB.dashboard.watchChatThreads().first;
      final messagesA = await clientA.dashboard
          .watchMessagesForThread(threadId)
          .first;
      final messagesB = await clientB.dashboard
          .watchMessagesForThread(threadId)
          .first;

      final threadExistsA = threadsA.any((thread) => thread.id == threadId);
      final threadExistsB = threadsB.any((thread) => thread.id == threadId);
      final msgExistsA = messagesA.any((message) => message.id == messageId);
      final msgExistsB = messagesB.any((message) => message.id == messageId);

      return !threadExistsA && !threadExistsB && !msgExistsA && !msgExistsB;
    },
  );
}

Future<void> _runPollCrud(
  E2eClientContext clientA,
  E2eClientContext clientB,
) async {
  final pollId = _uniqueId('poll');
  final endTime = DateTime.now().toUtc().add(const Duration(hours: 2));

  final created = PollItem(
    id: pollId,
    question: 'smoke poll created by A',
    approvedCount: 0,
    rejectedCount: 0,
    requiredVotes: 2,
    endTime: endTime,
    pendingVoters: const <PendingVoter>[],
    creatorId: clientA.identity,
  );
  await clientA.dashboard.savePoll(created);

  await expectEventually(
    description: 'clientB should receive created poll $pollId',
    condition: () async {
      final polls = await clientB.dashboard.watchPolls().first;
      return polls.any(
        (poll) => poll.id == pollId && poll.question == created.question,
      );
    },
  );

  final updated = PollItem(
    id: pollId,
    question: 'smoke poll updated by B',
    approvedCount: 1,
    rejectedCount: 0,
    requiredVotes: 2,
    endTime: endTime,
    pendingVoters: const <PendingVoter>[],
    creatorId: clientA.identity,
    votedUserIds: [clientB.identity],
  );
  await clientB.dashboard.savePoll(updated);

  await expectEventually(
    description: 'clientA should receive updated poll $pollId',
    condition: () async {
      final polls = await clientA.dashboard.watchPolls().first;
      return polls.any(
        (poll) =>
            poll.id == pollId &&
            poll.question == updated.question &&
            poll.approvedCount == 1,
      );
    },
  );

  await clientA.dashboard.deletePoll(pollId);

  await expectEventually(
    description: 'poll $pollId should be deleted on both clients',
    condition: () async {
      final pollsA = await clientA.dashboard.watchPolls().first;
      final pollsB = await clientB.dashboard.watchPolls().first;
      final existsA = pollsA.any((poll) => poll.id == pollId);
      final existsB = pollsB.any((poll) => poll.id == pollId);
      return !existsA && !existsB;
    },
  );
}

Future<void> _runGroupSettingsSync(
  E2eClientContext clientA,
  E2eClientContext clientB,
) async {
  final createdAt = DateTime.now().toUtc();

  final created = GroupSettings(
    id: 'group_settings',
    name: 'smoke-group-a',
    createdAt: createdAt,
    logicalTime: 1,
    groupType: GroupType.team,
    dataRoomName: clientA.room,
    ownerId: clientA.identity,
  );
  await clientA.dashboard.saveGroupSettings(created);

  await expectEventually(
    description: 'clientB should receive group settings from clientA',
    condition: () async {
      final settings = await clientB.dashboard.watchGroupSettings().first;
      return settings != null &&
          settings.id == 'group_settings' &&
          settings.name == created.name;
    },
  );

  final updated = GroupSettings(
    id: 'group_settings',
    name: 'smoke-group-b',
    createdAt: createdAt,
    logicalTime: 2,
    groupType: GroupType.guild,
    dataRoomName: clientA.room,
    ownerId: clientA.identity,
  );
  await clientB.dashboard.saveGroupSettings(updated);

  await expectEventually(
    description: 'clientA should receive updated group settings from clientB',
    condition: () async {
      final settings = await clientA.dashboard.watchGroupSettings().first;
      return settings != null &&
          settings.id == 'group_settings' &&
          settings.name == updated.name &&
          settings.groupType == GroupType.guild;
    },
  );
}

Future<void> _runRoleCrud(
  E2eClientContext clientA,
  E2eClientContext clientB,
) async {
  final roleId = _uniqueId('role');

  final created = Role(
    id: roleId,
    groupId: clientA.room,
    name: 'smoke-role-a',
    color: 0xFF2A9D8F,
    position: 1,
    permissions: 0,
  );
  await clientA.roles.saveRole(created);

  await expectEventually(
    description: 'clientB should receive role $roleId',
    condition: () async {
      final roles = await clientB.roles.watchRoles().first;
      return roles.any(
        (role) => role.id == roleId && role.name == created.name,
      );
    },
  );

  final updated = Role(
    id: roleId,
    groupId: clientA.room,
    name: 'smoke-role-b',
    color: 0xFFE76F51,
    position: 2,
    permissions: 4,
    isHoisted: true,
  );
  await clientB.roles.saveRole(updated);

  await expectEventually(
    description: 'clientA should receive updated role $roleId',
    condition: () async {
      final roles = await clientA.roles.watchRoles().first;
      return roles.any(
        (role) =>
            role.id == roleId && role.name == updated.name && role.isHoisted,
      );
    },
  );

  await clientA.roles.deleteRole(roleId);

  await expectEventually(
    description: 'role $roleId should be deleted on both clients',
    condition: () async {
      final rolesA = await clientA.roles.watchRoles().first;
      final rolesB = await clientB.roles.watchRoles().first;
      final existsA = rolesA.any((role) => role.id == roleId);
      final existsB = rolesB.any((role) => role.id == roleId);
      return !existsA && !existsB;
    },
  );
}

Future<void> _runMemberCrud(
  E2eClientContext clientA,
  E2eClientContext clientB,
) async {
  final memberId = _uniqueId('member');

  final created = GroupMember(id: memberId, roleIds: const <String>[]);
  await clientA.members.saveMember(created);

  await expectEventually(
    description: 'clientB should receive member $memberId',
    condition: () async {
      final members = await clientB.members.watchMembers().first;
      return members.any((member) => member.id == memberId);
    },
  );

  final updated = GroupMember(
    id: memberId,
    roleIds: const <String>['role-alpha', 'role-beta'],
  );
  await clientB.members.saveMember(updated);

  await expectEventually(
    description: 'clientA should receive updated member $memberId',
    condition: () async {
      final members = await clientA.members.watchMembers().first;
      return members.any(
        (member) => member.id == memberId && member.roleIds.length == 2,
      );
    },
  );

  await clientA.members.deleteMember(memberId);

  await expectEventually(
    description: 'member $memberId should be deleted on both clients',
    condition: () async {
      final membersA = await clientA.members.watchMembers().first;
      final membersB = await clientB.members.watchMembers().first;
      final existsA = membersA.any((member) => member.id == memberId);
      final existsB = membersB.any((member) => member.id == memberId);
      return !existsA && !existsB;
    },
  );
}

String _uniqueId(String prefix) {
  return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}
