import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cohortz/core/permissions/permission_flags.dart';
import 'package:cohortz/core/theme/dialog_button_styles.dart';
import 'package:cohortz/features/permissions/data/role_providers.dart';
import 'package:cohortz/features/permissions/domain/role_model.dart';

class RoleEditorDialog extends ConsumerStatefulWidget {
  final Role role;
  final bool canEdit;
  final bool canDelete;
  final String title;

  const RoleEditorDialog({
    super.key,
    required this.role,
    required this.canEdit,
    required this.canDelete,
    required this.title,
  });

  @override
  ConsumerState<RoleEditorDialog> createState() => _RoleEditorDialogState();
}

class _RoleEditorDialogState extends ConsumerState<RoleEditorDialog> {
  late TextEditingController _nameController;
  final ScrollController _scrollController = ScrollController();
  late int _color;
  late int _permissions;
  late bool _isHoisted;

  final List<int> _palette = const [
    0xFFE53935,
    0xFFD81B60,
    0xFF8E24AA,
    0xFF5E35B1,
    0xFF3949AB,
    0xFF1E88E5,
    0xFF039BE5,
    0xFF00ACC1,
    0xFF00897B,
    0xFF43A047,
    0xFF7CB342,
    0xFFFDD835,
    0xFFFFB300,
    0xFFF4511E,
    0xFF6D4C41,
    0xFF546E7A,
  ];

  List<_WidgetPermissionGroup> get _widgetPermissions => const [
    _WidgetPermissionGroup(
      label: 'Calendar',
      view: PermissionFlags.viewCalendar,
      interact: PermissionFlags.interactCalendar,
      create: PermissionFlags.createCalendar,
      edit: PermissionFlags.editCalendar,
      manage: PermissionFlags.manageCalendar,
    ),
    _WidgetPermissionGroup(
      label: 'Vault',
      view: PermissionFlags.viewVault,
      interact: PermissionFlags.interactVault,
      create: PermissionFlags.createVault,
      edit: PermissionFlags.editVault,
      manage: PermissionFlags.manageVault,
    ),
    _WidgetPermissionGroup(
      label: 'Tasks',
      view: PermissionFlags.viewTasks,
      interact: PermissionFlags.interactTasks,
      create: PermissionFlags.createTasks,
      edit: PermissionFlags.editTasks,
      manage: PermissionFlags.manageTasks,
    ),
    _WidgetPermissionGroup(
      label: 'Notes',
      view: PermissionFlags.viewNotes,
      create: PermissionFlags.createNotes,
      edit: PermissionFlags.editNotes,
      manage: PermissionFlags.manageNotes,
    ),
    _WidgetPermissionGroup(
      label: 'Chat',
      view: PermissionFlags.viewChat,
      create: PermissionFlags.createChatRooms,
      edit: PermissionFlags.editChat,
      manage: PermissionFlags.manageChat,
    ),
    _WidgetPermissionGroup(
      label: 'Polls',
      view: PermissionFlags.viewPolls,
      interact: PermissionFlags.interactPolls,
      create: PermissionFlags.createPolls,
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.role.name);
    _color = widget.role.color;
    _permissions = PermissionFlags.normalize(widget.role.permissions);
    _isHoisted = widget.role.isHoisted;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleAdministrator(bool value) async {
    if (value) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Grant Administrator?'),
          content: const Text(
            'Administrator grants all permissions, including dangerous actions. Continue?',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: dialogDestructiveButtonStyle(context),
              child: const Text('Grant'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      if (value) {
        _permissions |= PermissionFlags.administrator;
      } else {
        _permissions &= ~PermissionFlags.administrator;
      }
    });
  }

  void _togglePermission(int flag, bool value) {
    setState(() {
      if (value) {
        _permissions |= flag;
        if (flag == PermissionFlags.createChatRooms ||
            flag == PermissionFlags.editChatRooms ||
            flag == PermissionFlags.deleteChatRooms ||
            flag == PermissionFlags.startPrivateChats ||
            flag == PermissionFlags.leavePrivateChats) {
          _permissions |= PermissionFlags.viewChat;
        }
      } else {
        _permissions &= ~flag;
      }
    });
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title, style: TextStyle(color: theme.colorScheme.onSurface)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildWidgetPermissionTable(ThemeData theme) {
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FixedColumnWidth(54),
          2: FixedColumnWidth(72),
          3: FixedColumnWidth(72),
          4: FixedColumnWidth(72),
          5: FixedColumnWidth(72),
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
              _PermissionHeader(label: 'Create'),
              _PermissionHeader(label: 'Edit'),
              _PermissionHeader(label: 'Manage'),
            ],
          ),
          for (final group in _widgetPermissions)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    group.label,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _PermissionToggleCell(
                  value: (_permissions & group.view) != 0,
                  enabled: widget.canEdit,
                  onChanged: (value) => _toggleWidgetPermission(
                    group: group,
                    level: _WidgetPermissionLevel.view,
                    enabled: value,
                  ),
                ),
                if (group.interact != null)
                  _PermissionToggleCell(
                    value: (_permissions & group.interact!) != 0,
                    enabled: widget.canEdit,
                    onChanged: (value) => _toggleWidgetPermission(
                      group: group,
                      level: _WidgetPermissionLevel.interact,
                      enabled: value,
                    ),
                  )
                else
                  const _PermissionEmptyCell(),
                _PermissionToggleCell(
                  value:
                      group.create != null &&
                      (_permissions & group.create!) != 0,
                  enabled: widget.canEdit,
                  onChanged: (value) => _toggleWidgetPermission(
                    group: group,
                    level: _WidgetPermissionLevel.create,
                    enabled: value,
                  ),
                ),
                _PermissionToggleCell(
                  value: (_permissions & group.edit) != 0,
                  enabled: widget.canEdit,
                  onChanged: (value) => _toggleWidgetPermission(
                    group: group,
                    level: _WidgetPermissionLevel.edit,
                    enabled: value,
                  ),
                ),
                _PermissionToggleCell(
                  value: (_permissions & group.manage) != 0,
                  enabled: widget.canEdit,
                  onChanged: (value) => _toggleWidgetPermission(
                    group: group,
                    level: _WidgetPermissionLevel.manage,
                    enabled: value,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _toggleWidgetPermission({
    required _WidgetPermissionGroup group,
    required _WidgetPermissionLevel level,
    required bool enabled,
  }) {
    setState(() {
      switch (level) {
        case _WidgetPermissionLevel.view:
          if (enabled) {
            _permissions |= group.view;
          } else {
            _permissions &= ~group.view;
            if (group.label == 'Chat') {
              _permissions &= ~PermissionFlags.createChatRooms;
              _permissions &= ~PermissionFlags.editChatRooms;
              _permissions &= ~PermissionFlags.deleteChatRooms;
              _permissions &= ~PermissionFlags.startPrivateChats;
              _permissions &= ~PermissionFlags.leavePrivateChats;
            }
            if (group.interact != null) {
              _permissions &= ~group.interact!;
            }
            if (group.create != null) {
              _permissions &= ~group.create!;
            }
            _permissions &= ~group.edit;
            _permissions &= ~group.manage;
          }
          break;
        case _WidgetPermissionLevel.interact:
          if (group.interact == null) break;
          if (enabled) {
            _permissions |= group.interact!;
            _permissions |= group.view;
          } else {
            _permissions &= ~group.interact!;
            if (group.create != null) {
              _permissions &= ~group.create!;
            }
            _permissions &= ~group.edit;
            _permissions &= ~group.manage;
          }
          break;
        case _WidgetPermissionLevel.create:
          if (group.create == null) break;
          if (enabled) {
            _permissions |= group.create!;
            _permissions |= group.view;
            if (group.interact != null) {
              _permissions |= group.interact!;
            }
          } else {
            _permissions &= ~group.create!;
            _permissions &= ~group.edit;
            _permissions &= ~group.manage;
          }
          break;
        case _WidgetPermissionLevel.edit:
          if (enabled) {
            _permissions |= group.edit;
            _permissions |= group.view;
            if (group.interact != null) {
              _permissions |= group.interact!;
            }
            if (group.create != null) {
              _permissions |= group.create!;
            }
          } else {
            _permissions &= ~group.edit;
            _permissions &= ~group.manage;
          }
          break;
        case _WidgetPermissionLevel.manage:
          if (enabled) {
            _permissions |= group.manage;
            _permissions |= group.edit;
            _permissions |= group.view;
            if (group.interact != null) {
              _permissions |= group.interact!;
            }
            if (group.create != null) {
              _permissions |= group.create!;
            }
          } else {
            _permissions &= ~group.manage;
          }
          break;
      }

      if (group.edit == PermissionFlags.editPolls) {
        if ((_permissions &
                (PermissionFlags.editPolls | PermissionFlags.managePolls)) !=
            0) {
          _permissions |= PermissionFlags.createPolls;
        }
      }
    });
  }

  Future<void> _save() async {
    if (!widget.canEdit) return;
    final updated = widget.role.copyWith(
      name: _nameController.text.trim().isEmpty
          ? widget.role.name
          : _nameController.text.trim(),
      color: _color,
      permissions: PermissionFlags.canonicalize(_permissions),
      isHoisted: _isHoisted,
    );
    await ref.read(roleRepositoryProvider).saveRole(updated);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (!widget.canDelete) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Role?'),
        content: Text('Delete "${widget.role.name}"? This cannot be undone.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: dialogDestructiveButtonStyle(context),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await ref.read(roleRepositoryProvider).deleteRole(widget.role.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabledOpacity = widget.canEdit ? 1.0 : 0.45;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
        child: Column(
          children: [
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                controller: _scrollController,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  primary: false,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        enabled: widget.canEdit,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Role Name',
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Color',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.hintColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: disabledOpacity,
                        child: IgnorePointer(
                          ignoring: !widget.canEdit,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _palette.map((value) {
                              final color = Color(value);
                              final selected = _color == value;
                              return GestureDetector(
                                onTap: () => setState(() => _color = value),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color,
                                    border: Border.all(
                                      color: selected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outlineVariant
                                                .withValues(alpha: 0.5),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPermissionTile(
                        title: 'Hoist Role',
                        subtitle: 'Show role separately in member list.',
                        value: _isHoisted,
                        onChanged: widget.canEdit
                            ? (value) => setState(() => _isHoisted = value)
                            : null,
                      ),
                      const Divider(height: 32),
                      Text(
                        'Permissions',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPermissionTile(
                        title: 'Administrator',
                        subtitle: 'Bypasses all permission checks.',
                        value:
                            (_permissions & PermissionFlags.administrator) != 0,
                        onChanged: widget.canEdit ? _toggleAdministrator : null,
                      ),
                      _buildPermissionTile(
                        title: 'Manage Group',
                        subtitle: 'Edit name and avatar.',
                        value:
                            (_permissions & PermissionFlags.manageGroup) != 0,
                        onChanged: widget.canEdit
                            ? (value) => _togglePermission(
                                PermissionFlags.manageGroup,
                                value,
                              )
                            : null,
                      ),
                      _buildPermissionTile(
                        title: 'Manage Roles',
                        subtitle: 'Create and edit roles.',
                        value:
                            (_permissions & PermissionFlags.manageRoles) != 0,
                        onChanged: widget.canEdit
                            ? (value) => _togglePermission(
                                PermissionFlags.manageRoles,
                                value,
                              )
                            : null,
                      ),
                      _buildPermissionTile(
                        title: 'Manage Members',
                        subtitle: 'Kick and ban members.',
                        value:
                            (_permissions & PermissionFlags.manageMembers) != 0,
                        onChanged: widget.canEdit
                            ? (value) => _togglePermission(
                                PermissionFlags.manageMembers,
                                value,
                              )
                            : null,
                      ),
                      _buildPermissionTile(
                        title: 'Manage Invites',
                        subtitle: 'Create and revoke invite codes.',
                        value:
                            (_permissions & PermissionFlags.manageInvites) != 0,
                        onChanged: widget.canEdit
                            ? (value) => _togglePermission(
                                PermissionFlags.manageInvites,
                                value,
                              )
                            : null,
                      ),
                      _buildPermissionTile(
                        title: 'Mention Everyone',
                        subtitle: 'Use @everyone in chat.',
                        value:
                            (_permissions & PermissionFlags.mentionEveryone) !=
                            0,
                        onChanged: widget.canEdit
                            ? (value) => _togglePermission(
                                PermissionFlags.mentionEveryone,
                                value,
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chat Room Permissions',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPermissionTile(
                        title: 'Create Channels',
                        subtitle: 'Create public chat rooms.',
                        value:
                            (_permissions & PermissionFlags.createChatRooms) !=
                            0,
                        onChanged: widget.canEdit
                            ? (value) => _togglePermission(
                                PermissionFlags.createChatRooms,
                                value,
                              )
                            : null,
                      ),
                      _buildPermissionTile(
                        title: 'Edit Channels',
                        subtitle: 'Rename existing channels.',
                        value:
                            (_permissions & PermissionFlags.editChatRooms) != 0,
                        onChanged: widget.canEdit
                            ? (value) => _togglePermission(
                                PermissionFlags.editChatRooms,
                                value,
                              )
                            : null,
                      ),
                      _buildPermissionTile(
                        title: 'Delete Channels',
                        subtitle: 'Delete existing channels.',
                        value:
                            (_permissions & PermissionFlags.deleteChatRooms) !=
                            0,
                        onChanged: widget.canEdit
                            ? (value) => _togglePermission(
                                PermissionFlags.deleteChatRooms,
                                value,
                              )
                            : null,
                      ),
                      _buildPermissionTile(
                        title: 'Start Private Chats',
                        subtitle: 'Open direct message threads.',
                        value:
                            (_permissions &
                                PermissionFlags.startPrivateChats) !=
                            0,
                        onChanged: widget.canEdit
                            ? (value) => _togglePermission(
                                PermissionFlags.startPrivateChats,
                                value,
                              )
                            : null,
                      ),
                      _buildPermissionTile(
                        title: 'Leave Private Chats',
                        subtitle: 'Leave direct message threads.',
                        value:
                            (_permissions &
                                PermissionFlags.leavePrivateChats) !=
                            0,
                        onChanged: widget.canEdit
                            ? (value) => _togglePermission(
                                PermissionFlags.leavePrivateChats,
                                value,
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Widget Permissions',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildWidgetPermissionTable(theme),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  if (widget.canDelete)
                    ElevatedButton(
                      onPressed: _delete,
                      style: dialogDestructiveButtonStyle(context),
                      child: const Text('Delete Role'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: widget.canEdit ? _save : null,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetPermissionGroup {
  final String label;
  final int view;
  final int? interact;
  final int? create;
  final int edit;
  final int manage;

  const _WidgetPermissionGroup({
    required this.label,
    required this.view,
    this.interact,
    this.create,
    required this.edit,
    required this.manage,
  });
}

enum _WidgetPermissionLevel { view, interact, create, edit, manage }

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

class _PermissionToggleCell extends StatelessWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _PermissionToggleCell({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Switch.adaptive(
        value: value,
        onChanged: enabled ? onChanged : null,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _PermissionEmptyCell extends StatelessWidget {
  const _PermissionEmptyCell();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('—', style: TextStyle(color: Theme.of(context).hintColor)),
    );
  }
}
