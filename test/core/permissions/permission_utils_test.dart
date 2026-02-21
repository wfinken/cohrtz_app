import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionUtils.has', () {
    test('allows any permission for PermissionFlags.all', () {
      expect(
        PermissionUtils.has(PermissionFlags.all, PermissionFlags.manageMembers),
        isTrue,
      );
    });

    test('allows any permission for administrator bit', () {
      expect(
        PermissionUtils.has(
          PermissionFlags.administrator,
          PermissionFlags.manageMembers,
        ),
        isTrue,
      );
    });

    test('checks explicit permission bits for non-admin values', () {
      final permissions =
          PermissionFlags.manageRoles | PermissionFlags.editChat;

      expect(
        PermissionUtils.has(permissions, PermissionFlags.manageRoles),
        isTrue,
      );
      expect(
        PermissionUtils.has(permissions, PermissionFlags.manageMembers),
        isFalse,
      );
    });
  });
}
