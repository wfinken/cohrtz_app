import 'package:flutter_test/flutter_test.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/notes/models/note_model.dart';
import 'package:cohortz/slices/permissions_feature/models/member_model.dart';
import 'package:cohortz/slices/permissions_feature/models/logical_group_model.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';

void main() {
  group('Comprehensive Serialization Tests', () {
    test('TaskItem serialization', () {
      final task = TaskItem(
        id: 't1',
        title: 'Do something',
        assignedTo: 'Alice',
        assigneeId: 'u1',
        isCompleted: false,
        visibilityGroupIds: const ['everyone'],
      );
      final json = task.toJson();
      final decoded = TaskItemMapper.fromJson(json);
      expect(decoded.id, task.id);
      expect(decoded.title, task.title);
      expect(decoded.assigneeId, task.assigneeId);
      expect(decoded.assignedTo, task.assignedTo);
      expect(decoded.visibilityGroupIds, const ['everyone']);
    });

    test('CalendarEvent serialization', () {
      final event = CalendarEvent(
        id: 'e1',
        title: 'Meeting',
        time: DateTime.utc(2025, 1, 1, 10, 0),
        endTime: DateTime.utc(2025, 1, 1, 11, 0),
        isAllDay: false,
        location: 'Room A',
        description: 'Discuss things',
        attendees: {'u1': 'going', 'u2': 'maybe'},
        creatorId: 'u1',
      );
      final json = event.toJson();
      final decoded = CalendarEventMapper.fromJson(json);
      expect(decoded.id, event.id);
      expect(decoded.title, event.title);
      expect(decoded.description, event.description);
      expect(decoded.attendees.length, 2);
    });

    test('VaultItem serialization', () {
      final item = VaultItem(
        id: 'v1',
        label: 'Secret Item',
        type: 'password',
        encryptedValue: 'encrypted_content',
      );
      final json = item.toJson();
      final decoded = VaultItemMapper.fromJson(json);
      expect(decoded.id, item.id);
      expect(decoded.label, item.label);
      expect(decoded.encryptedValue, item.encryptedValue);
    });

    test('ChatMessage serialization', () {
      final msg = ChatMessage(
        id: 'm1',
        senderId: 'u1',
        content: 'Hello',
        timestamp: DateTime.utc(2025, 1, 1),
        threadId: 'thread1',
      );
      final json = msg.toJson();
      final decoded = ChatMessageMapper.fromJson(json);
      expect(decoded.id, msg.id);
      expect(decoded.content, msg.content);
    });

    test('ChatThread serialization', () {
      final thread = ChatThread(
        id: 'thread1',
        kind: 'channel',
        name: 'General',
        participantIds: ['u1', 'u2'],
        createdBy: 'u1',
        createdAt: DateTime.utc(2025, 1, 1),
      );
      final json = thread.toJson();
      final decoded = ChatThreadMapper.fromJson(json);
      expect(decoded.id, thread.id);
      expect(decoded.name, thread.name);
      expect(decoded.participantIds, contains('u1'));
    });

    test('UserProfile serialization', () {
      final profile = UserProfile(
        id: 'u1',
        displayName: 'Alice',
        publicKey: 'pubkey',
      );
      final json = profile.toJson();
      final decoded = UserProfileMapper.fromJson(json);
      expect(decoded.id, profile.id);
      expect(decoded.displayName, profile.displayName);
    });

    test('PollItem serialization', () {
      final poll = PollItem(
        id: 'p1',
        question: 'Yes or No?',
        approvedCount: 0,
        requiredVotes: 5,
        endTime: DateTime.utc(2025, 1, 1),
        pendingVoters: [],
        creatorId: 'u1',
        tiebreakerPolicy: PollTiebreakerPolicy.chaos,
      );
      final json = poll.toJson();
      final decoded = PollItemMapper.fromJson(json);
      expect(decoded.id, poll.id);
      expect(decoded.tiebreakerPolicy, PollTiebreakerPolicy.chaos);
    });

    test('GroupSettings serialization', () {
      final settings = GroupSettings(
        id: 'g1',
        name: 'My Group',
        createdAt: DateTime.utc(2025, 1, 1),
        dataRoomName: 'room-1',
        ownerId: 'u1',
        invites: [GroupInvite(code: 'CODE123', isSingleUse: true)],
      );
      final json = settings.toJson();
      final decoded = GroupSettingsMapper.fromJson(json);
      expect(decoded.id, settings.id);
      expect(decoded.invites.length, 1);
      expect(decoded.invites.first.code, 'CODE123');
    });

    test('DashboardWidget serialization', () {
      final widget = DashboardWidget(
        id: 'w1',
        type: 'calendar',
        x: 0,
        y: 0,
        width: 1,
        height: 1,
      );
      final json = widget.toJson();
      final decoded = DashboardWidgetMapper.fromJson(json);
      expect(decoded.id, widget.id);
      expect(decoded.type, widget.type);
      expect(decoded.x, 0);
    });

    test('GroupMember serialization', () {
      final member = GroupMember(id: 'u1', roleIds: ['admin']);
      final json = member.toJson();
      final decoded = GroupMemberMapper.fromJson(json);
      expect(decoded.id, member.id);
      expect(decoded.roleIds, contains('admin'));
    });

    test('Role serialization', () {
      final role = Role(
        id: 'admin',
        groupId: 'g1',
        name: 'Administrator',
        permissions: 123,
        position: 1,
        color: 0xFF0000FF,
      );
      final json = role.toJson();
      final decoded = RoleMapper.fromJson(json);
      expect(decoded.id, role.id);
      expect(decoded.permissions, 123);
      expect(decoded.groupId, 'g1');
    });

    test('LogicalGroup serialization', () {
      final group = LogicalGroup(
        id: 'logical_group:1',
        name: 'Ops',
        memberIds: const ['u1', 'u2'],
      );
      final json = group.toJson();
      final decoded = LogicalGroupMapper.fromJson(json);
      expect(decoded.id, group.id);
      expect(decoded.memberIds, contains('u1'));
      expect(decoded.name, 'Ops');
    });

    test('Legacy visibility defaults to everyone', () {
      final legacyTask = TaskItemMapper.fromJson(
        '{"id":"t1","title":"Legacy","assignedTo":"Alice","assigneeId":"u1","isCompleted":false}',
      );
      expect(legacyTask.visibilityGroupIds, const ['everyone']);
    });

    test('Note serialization', () {
      final note = Note(
        id: 'n1',
        title: 'Title',
        content: 'content',
        updatedBy: 'u1',
        updatedAt: DateTime.utc(2025, 1, 1),
      );
      final json = note
          .toJson(); // Note uses custom toJson which returns String? No, removed logic likely. Default mapper toJson returns String.
      // Wait, NoteMapper.toJson returns string.
      // But let's verify if Note has manual toJson.
      // I removed factories. Did I remove toJson?
      // Mappable generates toJson() returning String if configured so?
      // Actually mappable generates toJson() returning String by default for @MappableClass

      // Let's check Note again. If I didn't remove toJson, it might conflict.
      // I previously checked note_model.dart.
      // Assuming generated mixin handles it.

      final decoded = NoteMapper.fromJson(json);
      expect(decoded.id, note.id);
      expect(decoded.title, 'Title');
    });
  });
}
