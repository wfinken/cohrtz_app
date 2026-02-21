import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/app/di/app_providers.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/permissions_feature/state/member_providers.dart';
import 'package:cohortz/slices/permissions_feature/state/role_providers.dart';
import 'package:cohortz/slices/permissions_feature/models/member_model.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/members/ui/utils/role_sorting.dart';

class MemberRolesDialog extends ConsumerStatefulWidget {
  final UserProfile member;

  const MemberRolesDialog({super.key, required this.member});

  @override
  ConsumerState<MemberRolesDialog> createState() => _MemberRolesDialogState();
}

class _MemberRolesDialogState extends ConsumerState<MemberRolesDialog> {
  List<String> _selectedRoleIds = [];
  bool _initialized = false;

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

  int _calculatePermissions(List<Role> roles, List<String> roleIds) {
    int perms = 0;
    for (final role in roles) {
      if (roleIds.contains(role.id)) {
        perms |= role.permissions;
      }
    }
    if ((perms & PermissionFlags.administrator) != 0) {
      return PermissionFlags.all;
    }
    return PermissionFlags.normalize(perms);
  }

  Future<void> _toggleRole({
    required Role role,
    required bool enabled,
    required bool canEdit,
    required GroupMember member,
  }) async {
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You cannot manage roles higher than or equal to your own.',
          ),
        ),
      );
      return;
    }

    final nextRoleIds = [..._selectedRoleIds];
    if (enabled) {
      if (!nextRoleIds.contains(role.id)) {
        nextRoleIds.add(role.id);
      }
    } else {
      nextRoleIds.remove(role.id);
    }

    setState(() {
      _selectedRoleIds = nextRoleIds;
    });

    await ref
        .read(memberRepositoryProvider)
        .saveMember(member.copyWith(roleIds: nextRoleIds));
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(rolesProvider);
    final membersAsync = ref.watch(membersProvider);
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final settings = ref.watch(groupSettingsProvider).value;
    final isOwner = ref.watch(currentUserIsOwnerProvider);
    final myId = ref.watch(syncServiceProvider.select((s) => s.identity)) ?? '';

    return rolesAsync.when(
      data: (roles) {
        final sortedRoles = sortRolesByPermissionLevel(roles);

        final members = membersAsync.value ?? [];
        final targetMember = members.firstWhere(
          (m) => m.id == widget.member.id,
          orElse: () => GroupMember(id: widget.member.id, roleIds: const []),
        );

        if (!_initialized) {
          _selectedRoleIds = List<String>.from(targetMember.roleIds);
          _initialized = true;
        }

        final actorMember = members.firstWhere(
          (m) => m.id == myId,
          orElse: () => GroupMember(id: myId, roleIds: const []),
        );

        final actorHighestRole = _highestRoleForMember(
          actorMember,
          sortedRoles,
        );
        final targetIsOwner =
            settings?.ownerId.isNotEmpty == true &&
            settings?.ownerId == widget.member.id;

        final canManageRoles = permissionsAsync.maybeWhen(
          data: (permissions) =>
              PermissionUtils.has(permissions, PermissionFlags.manageRoles),
          orElse: () => false,
        );

        bool canEditRole(Role role) {
          if (!canManageRoles) return false;
          if (targetIsOwner) return false;
          if (isOwnerRole(role)) return false;
          if (isOwner) return true;
          if (actorHighestRole == null) return false;
          return role.position < actorHighestRole.position;
        }

        final effectivePermissions = _calculatePermissions(
          sortedRoles,
          _selectedRoleIds,
        );

        const widgetPermissions = [
          _WidgetPermissionGroup(
            label: 'Calendar',
            view: PermissionFlags.viewCalendar,
            interact: PermissionFlags.interactCalendar,
            edit: PermissionFlags.editCalendar,
            manage: PermissionFlags.manageCalendar,
          ),
          _WidgetPermissionGroup(
            label: 'Vault',
            view: PermissionFlags.viewVault,
            interact: PermissionFlags.interactVault,
            edit: PermissionFlags.editVault,
            manage: PermissionFlags.manageVault,
          ),
          _WidgetPermissionGroup(
            label: 'Tasks',
            view: PermissionFlags.viewTasks,
            interact: PermissionFlags.interactTasks,
            edit: PermissionFlags.editTasks,
            manage: PermissionFlags.manageTasks,
          ),
          _WidgetPermissionGroup(
            label: 'Notes',
            view: PermissionFlags.viewNotes,
            edit: PermissionFlags.editNotes,
            manage: PermissionFlags.manageNotes,
          ),
          _WidgetPermissionGroup(
            label: 'Chat',
            view: PermissionFlags.viewChat,
            edit: PermissionFlags.editChat,
            manage: PermissionFlags.manageChat,
          ),
          _WidgetPermissionGroup(
            label: 'Polls',
            view: PermissionFlags.viewPolls,
            interact: PermissionFlags.interactPolls,
            edit: PermissionFlags.editPolls,
            manage: PermissionFlags.managePolls,
          ),
          _WidgetPermissionGroup(
            label: 'Members',
            view: PermissionFlags.viewMembers,
            edit: PermissionFlags.editMembers,
            manage: PermissionFlags.manageMembers,
          ),
        ];
        final roleTiles = sortedRoles.map((role) {
          final enabled = _selectedRoleIds.contains(role.id);
          final canEdit = canEditRole(role);
          final tile = CheckboxListTile(
            value: enabled,
            onChanged: canEdit
                ? (value) {
                    _toggleRole(
                      role: role,
                      enabled: value ?? false,
                      canEdit: canEdit,
                      member: targetMember,
                    );
                  }
                : null,
            title: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(role.color),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(role.name)),
              ],
            ),
            subtitle: Text('Position ${role.position}'),
            controlAffinity: ListTileControlAffinity.leading,
          );
          if (canEdit) return tile;
          return InkWell(
            onTap: () {
              _toggleRole(
                role: role,
                enabled: enabled,
                canEdit: false,
                member: targetMember,
              );
            },
            child: tile,
          );
        }).toList();

        final roleContent = <Widget>[
          ...roleTiles,
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text('Effective Permissions'),
            childrenPadding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 12,
            ),
            children: [
              _PermissionSectionTitle(title: 'General'),
              _PermissionRow(
                label: 'Administrator',
                allowed: effectivePermissions == PermissionFlags.all,
              ),
              _PermissionRow(
                label: 'Manage Group',
                allowed: PermissionUtils.has(
                  effectivePermissions,
                  PermissionFlags.manageGroup,
                ),
              ),
              _PermissionRow(
                label: 'Manage Roles',
                allowed: PermissionUtils.has(
                  effectivePermissions,
                  PermissionFlags.manageRoles,
                ),
              ),
              _PermissionRow(
                label: 'Manage Members',
                allowed: PermissionUtils.has(
                  effectivePermissions,
                  PermissionFlags.manageMembers,
                ),
              ),
              _PermissionRow(
                label: 'Manage Invites',
                allowed: PermissionUtils.has(
                  effectivePermissions,
                  PermissionFlags.manageInvites,
                ),
              ),
              _PermissionRow(
                label: 'Mention Everyone',
                allowed: PermissionUtils.has(
                  effectivePermissions,
                  PermissionFlags.mentionEveryone,
                ),
              ),
              const SizedBox(height: 12),
              _PermissionSectionTitle(title: 'Chat Rooms'),
              _PermissionRow(
                label: 'Create Channels',
                allowed: PermissionUtils.has(
                  effectivePermissions,
                  PermissionFlags.createChatRooms,
                ),
              ),
              _PermissionRow(
                label: 'Edit Channels',
                allowed: PermissionUtils.has(
                  effectivePermissions,
                  PermissionFlags.editChatRooms,
                ),
              ),
              _PermissionRow(
                label: 'Delete Channels',
                allowed: PermissionUtils.has(
                  effectivePermissions,
                  PermissionFlags.deleteChatRooms,
                ),
              ),
              _PermissionRow(
                label: 'Start Private Chats',
                allowed: PermissionUtils.has(
                  effectivePermissions,
                  PermissionFlags.startPrivateChats,
                ),
              ),
              _PermissionRow(
                label: 'Leave Private Chats',
                allowed: PermissionUtils.has(
                  effectivePermissions,
                  PermissionFlags.leavePrivateChats,
                ),
              ),
              const SizedBox(height: 12),
              _PermissionSectionTitle(title: 'Widgets'),
              _PermissionMatrix(
                permissions: effectivePermissions,
                groups: widgetPermissions,
              ),
            ],
          ),
        ];

        final theme = Theme.of(context);
        final maxListHeight = MediaQuery.of(context).size.height * 0.6;
        final roleList = Theme(
          data: theme.copyWith(
            disabledColor: theme.colorScheme.onSurfaceVariant,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              shrinkWrap: true,
              primary: false,
              physics: const BouncingScrollPhysics(),
              children: roleContent,
            ),
          ),
        );

        return Dialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.member.displayName.isEmpty
                                  ? 'Member'
                                  : widget.member.displayName,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Assign roles to control permissions.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (targetIsOwner)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Owner',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!canManageRoles)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    child: Text(
                      'You do not have permission to manage roles.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  )
                else if (targetIsOwner)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    child: Text(
                      'Owner roles cannot be edited.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Flexible(child: roleList),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Row(
                    children: [
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
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

class _PermissionRow extends StatelessWidget {
  final String label;
  final bool allowed;

  const _PermissionRow({required this.label, required this.allowed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          Text(
            allowed ? 'Yes' : 'No',
            style: TextStyle(
              color: allowed
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionSectionTitle extends StatelessWidget {
  final String title;

  const _PermissionSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _WidgetPermissionGroup {
  final String label;
  final int view;
  final int? interact;
  final int edit;
  final int manage;

  const _WidgetPermissionGroup({
    required this.label,
    required this.view,
    this.interact,
    required this.edit,
    required this.manage,
  });
}

class _PermissionMatrix extends StatelessWidget {
  final int permissions;
  final List<_WidgetPermissionGroup> groups;

  const _PermissionMatrix({required this.permissions, required this.groups});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.1),
          1: FixedColumnWidth(52),
          2: FixedColumnWidth(74),
          3: FixedColumnWidth(90),
          4: FixedColumnWidth(70),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('Widget', style: headerStyle),
              ),
              _PermissionHeader(label: 'View'),
              _PermissionHeader(label: 'Interact'),
              _PermissionHeader(label: 'Create/Edit'),
              _PermissionHeader(label: 'Manage'),
            ],
          ),
          for (final group in groups)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    group.label,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                _PermissionCell(
                  allowed: PermissionUtils.has(permissions, group.view),
                ),
                _PermissionCell(
                  allowed: group.interact == null
                      ? null
                      : PermissionUtils.has(permissions, group.interact!),
                ),
                _PermissionCell(
                  allowed: PermissionUtils.has(permissions, group.edit),
                ),
                _PermissionCell(
                  allowed: PermissionUtils.has(permissions, group.manage),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PermissionHeader extends StatelessWidget {
  final String label;

  const _PermissionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PermissionCell extends StatelessWidget {
  final bool? allowed;

  const _PermissionCell({required this.allowed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (allowed == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          '—',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        allowed! ? 'Yes' : 'No',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: allowed!
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
