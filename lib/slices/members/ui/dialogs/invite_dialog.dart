import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/slices/permissions_feature/state/role_providers.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/members/ui/utils/role_sorting.dart';
import '../../../../app/di/app_providers.dart';

class InviteDialog extends ConsumerStatefulWidget {
  const InviteDialog({super.key});

  @override
  ConsumerState<InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<InviteDialog> {
  bool _isSingleUse = true;
  // Defaulting to 24 hours (1 Day)
  Duration _selectedExpiry = const Duration(days: 1);
  String? _selectedRoleId;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(groupSettingsProvider);
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final rolesAsync = ref.watch(rolesProvider);
    final canManageInvites = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.manageInvites),
      orElse: () => false,
    );

    final roles = sortRolesByPermissionLevel(
      rolesAsync
          .maybeWhen(data: (data) => data, orElse: () => const <Role>[])
          .where((role) => !isOwnerRole(role)),
    );
    final defaultRole = _resolveDefaultRole(roles);
    if (_selectedRoleId == null && defaultRole != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedRoleId = defaultRole.id);
      });
    }

    return settingsAsync.when(
      data: (settings) =>
          _buildDialogContent(context, settings, canManageInvites, roles),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => const Center(child: Text('Error loading settings')),
    );
  }

  Role? _resolveDefaultRole(List<Role> roles) {
    if (roles.isEmpty) return null;
    for (final role in roles) {
      if (role.name.toLowerCase() == 'member') {
        return role;
      }
    }
    return roles.last;
  }

  String _inviteRoleLabel(GroupInvite invite, Map<String, Role> roleById) {
    if (invite.roleId.isEmpty) return 'Default';
    return roleById[invite.roleId]?.name ?? 'Unknown';
  }

  Widget _buildRolePicker(
    BuildContext context,
    List<Role> roles,
    bool canManageInvites,
  ) {
    if (roles.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Permissions Group',
            style: TextStyle(
              color: Theme.of(context).hintColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No roles available',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      );
    }

    final defaultRole = _resolveDefaultRole(roles);
    final hasRole = roles.any((role) => role.id == _selectedRoleId);
    final effectiveRoleId = roles.isNotEmpty
        ? (hasRole ? _selectedRoleId : defaultRole?.id)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Permissions Group',
          style: TextStyle(
            color: Theme.of(context).hintColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effectiveRoleId,
              isExpanded: true,
              dropdownColor: Theme.of(context).cardColor,
              items: roles
                  .map(
                    (role) => DropdownMenuItem(
                      value: role.id,
                      child: Text(
                        role.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: !canManageInvites
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _selectedRoleId = value);
                    },
              hint: const Text('Select permissions group'),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogContent(
    BuildContext context,
    GroupSettings? currentSettings,
    bool canManageInvites,
    List<Role> roles,
  ) {
    final inviteProcess = ref.read(inviteManagementProcessProvider);
    final settings = inviteProcess.resolveSettings(currentSettings);
    final roleById = {for (final role in roles) role.id: role};

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_add,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Invite Members',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (!canManageInvites) ...[
              const SizedBox(height: 12),
              Text(
                'You do not have permission to manage invites.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Active Invites',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (settings.invites.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No active invites.',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ...settings.invites.map(
              (invite) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.vpn_key,
                      size: 16,
                      color: Theme.of(context).hintColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${invite.isSingleUse ? "Single-use" : "Multi-use"}${invite.expiresAt != null ? ", expires ${invite.expiresAt!.toLocal().toString().split('.')[0]}" : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Permissions: ${_inviteRoleLabel(invite, roleById)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: 'Copy Code',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: invite.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied ${invite.code} to clipboard'),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 16,
                        color: Colors.red,
                      ),
                      tooltip: 'Revoke Invite',
                      onPressed: canManageInvites
                          ? () async {
                              await inviteProcess.revokeInvite(
                                currentSettings: settings,
                                code: invite.code,
                              );
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 32),
            Text(
              'Create New Invite',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text(
                      'Single-use',
                      style: TextStyle(fontSize: 14),
                    ),
                    value: _isSingleUse,
                    onChanged: (v) => setState(() => _isSingleUse = v ?? true),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Duration>(
                        value: _selectedExpiry,
                        isExpanded: true,
                        dropdownColor: Theme.of(context).cardColor,
                        items: const [
                          DropdownMenuItem(
                            value: Duration(hours: 1),
                            child: Text(
                              "1 Hour",
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          DropdownMenuItem(
                            value: Duration(days: 1),
                            child: Text(
                              "1 Day",
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          DropdownMenuItem(
                            value: Duration(days: 7),
                            child: Text(
                              "7 Days",
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedExpiry = v);
                          }
                        },
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRolePicker(context, roles, canManageInvites),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canManageInvites
                    ? () async {
                        await inviteProcess.createInvite(
                          currentSettings: settings,
                          isSingleUse: _isSingleUse,
                          expiry: _selectedExpiry,
                          roleId: _selectedRoleId ?? '',
                        );
                      }
                    : null,
                icon: const Icon(Icons.add),
                label: const Text('Generate Invite Code'),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
