import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/permissions_feature/models/member_model.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';
import 'package:cohortz/slices/sync/runtime/crdt_service.dart';

class PermissionService {
  final CrdtService _crdtService;

  PermissionService(this._crdtService);

  Future<int> calculatePermissions(String roomName, String memberId) async {
    final ownerId = await _getOwnerId(roomName);
    if (ownerId != null && ownerId.isNotEmpty && ownerId == memberId) {
      return PermissionFlags.all;
    }

    final member = await _getMember(roomName, memberId);
    if (member == null) return PermissionFlags.none;

    final roles = await _getRoles(roomName);
    int finalPermissions = 0;
    for (final role in roles) {
      if (member.roleIds.contains(role.id)) {
        finalPermissions |= role.permissions;
      }
    }

    if ((finalPermissions & PermissionFlags.administrator) != 0) {
      return PermissionFlags.all;
    }

    return PermissionFlags.normalize(finalPermissions);
  }

  Future<bool> hasPermission(
    String roomName,
    String memberId,
    int permission,
  ) async {
    final perms = await calculatePermissions(roomName, memberId);
    return PermissionUtils.has(perms, permission);
  }

  Future<bool> isBootstrapState(String roomName) async {
    final hasRoles = await _hasAnyRecords(roomName, 'roles');
    final hasMembers = await _hasAnyRecords(roomName, 'members');
    return !hasRoles && !hasMembers;
  }

  Future<Role?> highestRole(String roomName, GroupMember? member) async {
    if (member == null) return null;
    final roles = await _getRoles(roomName);
    return _highestRoleForMember(member, roles);
  }

  Future<bool> canInteractMember({
    required String roomName,
    required String actorId,
    required String targetId,
  }) async {
    final ownerId = await _getOwnerId(roomName);
    if (ownerId != null && ownerId.isNotEmpty) {
      if (actorId == ownerId) return true;
      if (targetId == ownerId) return false;
    }

    final roles = await _getRoles(roomName);
    final actor = await _getMember(roomName, actorId);
    final target = await _getMember(roomName, targetId);

    final actorTop = _highestRoleForMember(actor, roles);
    final targetTop = _highestRoleForMember(target, roles);

    final actorPos = actorTop?.position ?? -1;
    final targetPos = targetTop?.position ?? -1;

    return actorPos > targetPos;
  }

  Future<bool> canInteractRole({
    required String roomName,
    required String actorId,
    required Role targetRole,
  }) async {
    final ownerId = await _getOwnerId(roomName);
    if (ownerId != null && ownerId.isNotEmpty && actorId == ownerId) {
      return true;
    }

    final roles = await _getRoles(roomName);
    final actor = await _getMember(roomName, actorId);
    final actorTop = _highestRoleForMember(actor, roles);
    final actorPos = actorTop?.position ?? -1;

    return actorPos > targetRole.position;
  }

  Role? _highestRoleForMember(GroupMember? member, List<Role> roles) {
    if (member == null) return null;
    Role? top;
    for (final role in roles) {
      if (!member.roleIds.contains(role.id)) continue;
      if (top == null || role.position > top.position) {
        top = role;
      }
    }
    return top;
  }

  Future<GroupMember?> _getMember(String roomName, String memberId) async {
    final rows = await _crdtService.query(
      roomName,
      'SELECT value FROM members WHERE id = ?',
      [memberId],
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'] as String? ?? '';
    if (value.isEmpty) return null;
    return GroupMemberMapper.fromJson(value);
  }

  Future<List<Role>> _getRoles(String roomName) async {
    final rows = await _crdtService.query(roomName, 'SELECT value FROM roles');
    final roles = <Role>[];
    for (final row in rows) {
      final value = row['value'] as String? ?? '';
      if (value.isEmpty) continue;
      try {
        roles.add(RoleMapper.fromJson(value));
      } catch (_) {}
    }
    return roles;
  }

  Future<bool> _hasAnyRecords(String roomName, String tableName) async {
    final rows = await _crdtService.query(
      roomName,
      'SELECT value FROM $tableName LIMIT 1',
    );
    if (rows.isEmpty) return false;
    final value = rows.first['value'] as String? ?? '';
    return value.isNotEmpty;
  }

  Future<String?> _getOwnerId(String roomName) async {
    final rows = await _crdtService.query(
      roomName,
      'SELECT value FROM group_settings WHERE id = ?',
      ['group_settings'],
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'] as String? ?? '';
    if (value.isEmpty) return null;
    try {
      final settings = GroupSettingsMapper.fromJson(value);
      if (settings.ownerId.isEmpty) return null;
      return settings.ownerId;
    } catch (_) {
      return null;
    }
  }
}
