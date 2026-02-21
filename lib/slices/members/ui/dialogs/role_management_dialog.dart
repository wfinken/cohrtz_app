import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/app/di/app_providers.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/permissions_feature/state/member_providers.dart';
import 'package:cohortz/slices/permissions_feature/state/role_providers.dart';
import 'package:cohortz/slices/permissions_feature/models/member_model.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';
import 'package:cohortz/slices/members/ui/utils/role_sorting.dart';

import 'role_editor_dialog.dart';

class RoleManagementDialog extends ConsumerStatefulWidget {
  const RoleManagementDialog({super.key});

  @override
  ConsumerState<RoleManagementDialog> createState() =>
      _RoleManagementDialogState();
}

class _RoleManagementDialogState extends ConsumerState<RoleManagementDialog> {
  final _uuid = const Uuid();

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

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(rolesProvider);
    final membersAsync = ref.watch(membersProvider);
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final isOwner = ref.watch(currentUserIsOwnerProvider);
    final myId = ref.watch(syncServiceProvider.select((s) => s.identity)) ?? '';

    return rolesAsync.when(
      data: (roles) {
        final sortedRoles = sortRolesByPermissionLevel(roles);

        final members = membersAsync.value ?? [];
        final member = members.firstWhere(
          (m) => m.id == myId,
          orElse: () => GroupMember(id: myId, roleIds: const []),
        );
        final highestRole = _highestRoleForMember(member, roles);
        final maxPosition = roles.fold<int>(
          0,
          (maxValue, role) =>
              role.position > maxValue ? role.position : maxValue,
        );

        final canManageRoles = permissionsAsync.maybeWhen(
          data: (permissions) =>
              PermissionUtils.has(permissions, PermissionFlags.manageRoles),
          orElse: () => false,
        );

        bool canManageRole(Role role) {
          if (isOwnerRole(role)) return false;
          if (isOwner) return true;
          if (highestRole == null) return false;
          return role.position < highestRole.position;
        }

        return Dialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Roles',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    if (canManageRoles)
                      ElevatedButton.icon(
                        onPressed: () async {
                          final roomName =
                              ref
                                  .read(dashboardRepositoryProvider)
                                  .currentRoomName ??
                              '';
                          if (roomName.isEmpty) return;

                          final newRole = Role(
                            id: 'role:${_uuid.v7()}',
                            groupId: roomName,
                            name: 'New Role',
                            color: 0xFF546E7A,
                            position: maxPosition + 1,
                            permissions: PermissionFlags.none,
                          );

                          await showDialog(
                            context: context,
                            builder: (_) => RoleEditorDialog(
                              role: newRole,
                              canEdit: true,
                              canDelete: false,
                              title: 'Create Role',
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create Role'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!canManageRoles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'You do not have permission to manage roles.',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  ),
                ListView.builder(
                  shrinkWrap: true,
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedRoles.length,
                  itemBuilder: (context, index) {
                    final role = sortedRoles[index];
                    final memberCount = members
                        .where((m) => m.roleIds.contains(role.id))
                        .length;
                    final canEditRole = canManageRoles && canManageRole(role);

                    return Card(
                      key: ValueKey(role.id),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        enabled: canEditRole,
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Color(role.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          role.name,
                          style: TextStyle(
                            color: canEditRole
                                ? null
                                : Theme.of(context).hintColor,
                          ),
                        ),
                        subtitle: Text(
                          '$memberCount members',
                          style: TextStyle(
                            color: canEditRole
                                ? null
                                : Theme.of(context).hintColor,
                          ),
                        ),
                        trailing: !canEditRole
                            ? Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: Theme.of(context).hintColor,
                              )
                            : null,
                        onTap: () async {
                          if (isOwnerRole(role)) {
                            await showDialog(
                              context: context,
                              builder: (_) => RoleEditorDialog(
                                role: role,
                                canEdit: false,
                                canDelete: false,
                                title: 'Owner Role',
                              ),
                            );
                            return;
                          }

                          if (!canEditRole) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'You cannot edit roles higher than your own.',
                                ),
                              ),
                            );
                            return;
                          }

                          await showDialog(
                            context: context,
                            builder: (_) => RoleEditorDialog(
                              role: role,
                              canEdit: canEditRole,
                              canDelete: canEditRole,
                              title: 'Edit Role',
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error loading roles: $err'),
        ),
      ),
    );
  }
}
