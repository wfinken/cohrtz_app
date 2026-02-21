import 'package:flutter_test/flutter_test.dart';

import 'package:cohortz/slices/members/ui/utils/role_sorting.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';

void main() {
  group('role sorting', () {
    test('owner role is always first', () {
      final roles = [
        _role(
          id: 'admin',
          name: 'Admin',
          permissions: PermissionFlags.administrator,
          position: 10,
        ),
        _role(id: 'owner', name: 'OWNER', permissions: PermissionFlags.none),
        _role(
          id: 'mod',
          name: 'Moderator',
          permissions: PermissionFlags.manageMembers,
          position: 20,
        ),
      ];

      final sorted = sortRolesByPermissionLevel(roles);
      expect(sorted.first.id, 'owner');
    });

    test('weighted hierarchy ranks admin above manage above edit', () {
      final roles = [
        _role(
          id: 'editor',
          name: 'Editor',
          permissions: PermissionFlags.editNotes,
          position: 30,
        ),
        _role(
          id: 'manager',
          name: 'Manager',
          permissions: PermissionFlags.manageMembers,
          position: 20,
        ),
        _role(
          id: 'admin',
          name: 'Admin',
          permissions: PermissionFlags.administrator,
          position: 10,
        ),
      ];

      final sorted = sortRolesByPermissionLevel(roles);
      expect(sorted.map((role) => role.id).toList(), [
        'admin',
        'manager',
        'editor',
      ]);
    });

    test('tie-breakers use position then name then id', () {
      final roles = [
        _role(
          id: 'b',
          name: 'Beta',
          permissions: PermissionFlags.viewNotes,
          position: 1,
        ),
        _role(
          id: 'a',
          name: 'Beta',
          permissions: PermissionFlags.viewNotes,
          position: 1,
        ),
        _role(
          id: 'c',
          name: 'Alpha',
          permissions: PermissionFlags.viewNotes,
          position: 1,
        ),
        _role(
          id: 'd',
          name: 'Delta',
          permissions: PermissionFlags.viewNotes,
          position: 2,
        ),
      ];

      final sorted = sortRolesByPermissionLevel(roles);
      expect(sorted.map((role) => role.id).toList(), ['d', 'c', 'a', 'b']);
    });

    test('owner role detection is case-insensitive', () {
      expect(
        isOwnerRole(_role(id: '1', name: ' Owner ', permissions: 0)),
        isTrue,
      );
      expect(
        isOwnerRole(_role(id: '2', name: 'Admin', permissions: 0)),
        isFalse,
      );
    });
  });
}

Role _role({
  required String id,
  required String name,
  required int permissions,
  int position = 0,
}) {
  return Role(
    id: id,
    groupId: 'g1',
    name: name,
    color: 0xFF546E7A,
    position: position,
    permissions: permissions,
  );
}
