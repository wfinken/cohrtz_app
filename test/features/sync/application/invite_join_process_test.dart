import 'dart:convert';

import 'package:cohortz/shared/security/group_identity_service.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_feature/models/member_model.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';
import 'package:cohortz/slices/sync/orchestration/processes/invite_join_process.dart';
import 'package:cohortz/slices/sync/orchestration/processes/network_recovery_process.dart';
import 'package:cohortz/slices/sync/orchestration/sync_service.dart';
import 'package:cohortz/slices/sync/runtime/crdt_service.dart';
import 'package:cohortz/slices/sync/runtime/hybrid_time_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mocks.dart';

class _MemoryCrdtService extends CrdtService {
  final Map<String, String> members = {};
  final Map<String, String> roles = {};

  @override
  Future<List<Map<String, Object?>>> query(
    String roomName,
    String sql, [
    List<Object?>? args,
  ]) async {
    if (sql.contains('FROM members WHERE id = ?')) {
      final id = args?.isNotEmpty == true ? (args!.first as String) : '';
      final value = members[id];
      if (value == null) return [];
      return [
        {'value': value},
      ];
    }
    if (sql.contains('SELECT id, value FROM members')) {
      return members.entries
          .map((entry) => {'id': entry.key, 'value': entry.value})
          .toList(growable: false);
    }
    if (sql.contains('FROM roles')) {
      return roles.values
          .map((value) => {'value': value})
          .toList(growable: false);
    }
    return [];
  }

  @override
  Future<void> put(
    String roomName,
    String key,
    String value, {
    String tableName = 'cohrtz',
  }) async {
    if (tableName == 'members') {
      members[key] = value;
      return;
    }
    if (tableName == 'roles') {
      roles[key] = value;
    }
  }
}

class _TestSyncService extends SyncService {
  _TestSyncService()
    : super(
        connectionManager: FakeConnectionManager(),
        groupManager: FakeGroupManager(),
        keyManager: FakeKeyManager(),
        inviteHandler: FakeInviteHandler(),
        networkRecoveryProcess: NetworkRecoveryProcess(
          connectionManager: FakeConnectionManager(),
        ),
      );
}

InviteJoinProcess _buildProcess(_MemoryCrdtService crdt) {
  final syncService = _TestSyncService();
  final keyManager = FakeKeyManager();
  final groupIdentity = GroupIdentityService(
    securityService: FakeSecurityService(),
    secureStorage: FakeSecureStorageService(),
  );
  final hybridTime = HybridTimeService(getLocalParticipantId: () => 'local-id');

  return InviteJoinProcess(
    syncService: syncService,
    keyManager: keyManager,
    groupIdentityService: groupIdentity,
    crdtService: crdt,
    hybridTimeService: hybridTime,
    onProcessStart: (_) {},
    onStepUpdate: (_, __) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InviteJoinProcess membership repair', () {
    test(
      'maps canonical member identity to current identity on reconnect',
      () async {
        final crdt = _MemoryCrdtService();
        const roomName = 'room-a';
        const canonicalId = '019c958c-aa86-7a43-aecc-42df4aa1aac2';
        const memberRoleId = 'role:member';
        const currentId = 'user:$canonicalId';

        crdt.members[canonicalId] = jsonEncode(
          GroupMember(id: canonicalId, roleIds: const [memberRoleId]).toMap(),
        );
        crdt.roles[memberRoleId] = jsonEncode(
          Role(
            id: memberRoleId,
            groupId: roomName,
            name: 'Member',
            color: 0,
            position: 10,
            permissions: PermissionFlags.defaultMember,
          ).toMap(),
        );

        final process = _buildProcess(crdt);
        final repaired = await process.ensureMembershipAfterReconnect(
          roomName: roomName,
          memberId: currentId,
        );

        expect(repaired, isTrue);
        expect(crdt.members.containsKey(currentId), isTrue);
        final mapped = GroupMemberMapper.fromJson(crdt.members[currentId]!);
        expect(mapped.roleIds, contains(memberRoleId));
      },
    );

    test(
      'assigns default member role when local member row is missing',
      () async {
        final crdt = _MemoryCrdtService();
        const roomName = 'room-b';
        const memberId = 'user:member-1';
        const memberRoleId = 'role:member';

        crdt.roles[memberRoleId] = jsonEncode(
          Role(
            id: memberRoleId,
            groupId: roomName,
            name: 'Member',
            color: 0,
            position: 10,
            permissions: PermissionFlags.defaultMember,
          ).toMap(),
        );

        final process = _buildProcess(crdt);
        final repaired = await process.ensureMembershipAfterReconnect(
          roomName: roomName,
          memberId: memberId,
        );

        expect(repaired, isTrue);
        expect(crdt.members.containsKey(memberId), isTrue);
        final mapped = GroupMemberMapper.fromJson(crdt.members[memberId]!);
        expect(mapped.roleIds, contains(memberRoleId));
      },
    );

    test(
      'host bootstrap recreates group settings, roles, and owner member',
      () async {
        final crdt = _MemoryCrdtService();
        const roomName = 'room-host';
        const hostId = 'user:host-1';

        final process = _buildProcess(crdt);
        final repaired = await process.ensureHostBootstrapAfterReconnect(
          roomName: roomName,
          hostId: hostId,
          groupName: 'My Group',
        );

        expect(repaired, isTrue);
        expect(crdt.roles.containsKey('role:owner'), isTrue);
        expect(crdt.roles.containsKey('role:member'), isTrue);
        expect(crdt.members.containsKey(hostId), isTrue);

        final ownerMember = GroupMemberMapper.fromJson(crdt.members[hostId]!);
        expect(ownerMember.roleIds, contains('role:owner'));
      },
    );
  });
}
