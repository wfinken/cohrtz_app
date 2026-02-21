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

import 'role_editor_dialog.dart';

class RoleManagementDialog extends ConsumerStatefulWidget {
  const RoleManagementDialog({super.key});

  @override
  ConsumerState<RoleManagementDialog> createState() =>
      _RoleManagementDialogState();
}

class _RoleManagementDialogState extends ConsumerState<RoleManagementDialog> {
  final _uuid = const Uuid();
  List<Role> _roles = [];
  List<String> _roleOrder = [];

  void _syncRoles(List<Role> roles) {
    final order = roles.map((r) => r.id).toList();
    if (_roleOrder.length != order.length || !_listsEqual(_roleOrder, order)) {
      _roles = roles;
      _roleOrder = order;
    }
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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

  Future<void> _persistOrder({
    required List<Role> roles,
    required bool updateAll,
    required Role? highestRole,
  }) async {
    if (roles.isEmpty) return;
    final repo = ref.read(roleRepositoryProvider);

    if (updateAll) {
      for (int i = 0; i < roles.length; i++) {
        final newPosition = (roles.length - i) * 10;
        final role = roles[i];
        if (role.position != newPosition) {
          await repo.saveRole(role.copyWith(position: newPosition));
        }
      }
      return;
    }

    if (highestRole == null) return;

    final editableRoles = roles.where((role) {
      return role.position < highestRole.position;
    }).toList();

    if (editableRoles.isEmpty) return;

    var base = highestRole.position - 1;
    if (base < editableRoles.length) base = editableRoles.length;

    for (int i = 0; i < editableRoles.length; i++) {
      final role = editableRoles[i];
      final newPosition = base - i;
      if (role.position != newPosition) {
        await repo.saveRole(role.copyWith(position: newPosition));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(rolesProvider);
    final membersAsync = ref.watch(membersProvider);
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final isOwner = ref.watch(currentUserIsOwnerProvider);
    final myId =
        ref.watch(syncServiceProvider.select((s) => s.identity)) ??
        ref.watch(identityServiceProvider).profile?.id ??
        '';

    return rolesAsync.when(
      data: (roles) {
        final sorted = List<Role>.from(roles)
          ..sort((a, b) => b.position.compareTo(a.position));
        _syncRoles(sorted);

        final members = membersAsync.value ?? [];
        final member = members.firstWhere(
          (m) => m.id == myId,
          orElse: () => GroupMember(id: myId, roleIds: const []),
        );
        final highestRole = _highestRoleForMember(member, sorted);

        final canManageRoles = permissionsAsync.maybeWhen(
          data: (permissions) =>
              PermissionUtils.has(permissions, PermissionFlags.manageRoles),
          orElse: () => false,
        );

        bool canManageRole(Role role) {
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

                          final maxPosition = sorted.isEmpty
                              ? 0
                              : sorted.first.position;
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
                ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  shrinkWrap: true,
                  itemCount: _roles.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (!canManageRoles) return;
                    if (_roles.isEmpty) return;

                    if (newIndex > oldIndex) newIndex -= 1;

                    final editableIndices = <int>[];
                    for (int i = 0; i < _roles.length; i++) {
                      if (canManageRole(_roles[i])) {
                        editableIndices.add(i);
                      }
                    }

                    if (!editableIndices.contains(oldIndex)) return;

                    final sourceEditableIndex = editableIndices.indexOf(
                      oldIndex,
                    );
                    final targetEditableIndex = editableIndices
                        .where((i) => i < newIndex)
                        .length
                        .clamp(0, editableIndices.length);

                    final editableRoles = _roles
                        .where((role) => canManageRole(role))
                        .toList();

                    if (sourceEditableIndex < 0 ||
                        sourceEditableIndex >= editableRoles.length) {
                      return;
                    }

                    final movedRole = editableRoles.removeAt(
                      sourceEditableIndex,
                    );
                    final insertIndex = targetEditableIndex.clamp(
                      0,
                      editableRoles.length,
                    );
                    editableRoles.insert(insertIndex, movedRole);

                    final updated = <Role>[];
                    int editableCursor = 0;
                    for (int i = 0; i < _roles.length; i++) {
                      if (canManageRole(_roles[i])) {
                        updated.add(editableRoles[editableCursor]);
                        editableCursor += 1;
                      } else {
                        updated.add(_roles[i]);
                      }
                    }

                    setState(() {
                      _roles = updated;
                      _roleOrder = updated.map((r) => r.id).toList();
                    });

                    await _persistOrder(
                      roles: _roles,
                      updateAll: isOwner,
                      highestRole: highestRole,
                    );
                  },
                  itemBuilder: (context, index) {
                    final role = _roles[index];
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!canEditRole)
                              Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: Theme.of(context).hintColor,
                              ),
                            if (canEditRole)
                              ReorderableDragStartListener(
                                index: index,
                                child: Icon(
                                  Icons.drag_handle,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        onTap: () async {
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
