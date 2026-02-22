import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/slices/permissions_core/visibility_acl.dart';
import 'package:cohortz/shared/theme/tokens/dialog_button_styles.dart';

import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/permissions_feature/models/logical_group_model.dart';
import 'package:cohortz/slices/permissions_feature/state/logical_group_providers.dart';
import 'package:cohortz/slices/permissions_feature/ui/widgets/visibility_group_selector.dart';
import '../../../../app/di/app_providers.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/dashboard_shell/ui/widgets/skeleton_loader.dart';
import '../dialogs/add_vault_dialog.dart';
import 'package:cohortz/slices/dashboard_shell/ui/widgets/ghost_add_button.dart';

class VaultWidget extends ConsumerStatefulWidget {
  const VaultWidget({super.key});

  @override
  ConsumerState<VaultWidget> createState() => _VaultWidgetState();
}

class _VaultWidgetState extends ConsumerState<VaultWidget> {
  String _filter = 'all'; // all, password, card, wifi

  @override
  Widget build(BuildContext context) {
    final vaultAsync = ref.watch(vaultStreamProvider);
    final settingsAsync = ref.watch(groupSettingsProvider);
    final groupType = settingsAsync.value?.groupType ?? GroupType.family;
    final logicalGroups = ref.watch(logicalGroupsProvider);
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final canCreateVault = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.createVault),
      orElse: () => false,
    );
    final canManageVault = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.manageVault),
      orElse: () => false,
    );
    final isAdmin = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.administrator),
      orElse: () => false,
    );
    final myId = ref.watch(syncServiceProvider.select((s) => s.identity));

    final content = Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterButton(
                icon: Icons.layers,
                isActive: _filter == 'all',
                onTap: () => setState(() => _filter = 'all'),
                tooltip: 'All',
              ),
              const SizedBox(width: 8),
              _FilterButton(
                icon: Icons.key,
                isActive: _filter == 'password',
                onTap: () => setState(() => _filter = 'password'),
                tooltip: 'Passwords',
              ),
              const SizedBox(width: 8),
              _FilterButton(
                icon: Icons.credit_card,
                isActive: _filter == 'card',
                onTap: () => setState(() => _filter = 'card'),
                tooltip: 'Cards',
              ),
              const SizedBox(width: 8),
              _FilterButton(
                icon: Icons.wifi,
                isActive: _filter == 'wifi',
                onTap: () => setState(() => _filter = 'wifi'),
                tooltip: 'WiFi',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        vaultAsync.when(
          data: (items) {
            final filteredItems = _filter == 'all'
                ? items
                : items.where((i) => i.type == _filter).toList();

            final hasMore = filteredItems.length > 2;

            final canInteractVault = permissionsAsync.maybeWhen(
              data: (permissions) => PermissionUtils.has(
                permissions,
                PermissionFlags.interactVault,
              ),
              orElse: () => false,
            );
            return filteredItems.isEmpty
                ? (canCreateVault || canManageVault || isAdmin)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GhostAddButton(
                              label: 'Add ${groupType.vaultSingular}',
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 4,
                              ),
                              margin: const EdgeInsets.only(top: 4, bottom: 12),
                              borderRadius: 8,
                              onTap: () => showDialog(
                                context: context,
                                builder: (_) => const AddVaultDialog(),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'No ${groupType.vaultTitle.toLowerCase()} items',
                          style: TextStyle(color: Theme.of(context).hintColor),
                        )
                : Flexible(
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ...filteredItems.map((item) {
                                      final isCreator =
                                          myId != null &&
                                          item.creatorId.isNotEmpty &&
                                          item.creatorId == myId;
                                      final canDelete =
                                          (canManageVault &&
                                              (isAdmin ||
                                                  isCreator ||
                                                  item.creatorId.isEmpty)) ||
                                          (isCreator &&
                                              item.creatorId.isNotEmpty);
                                      final canEditVisibility =
                                          isAdmin ||
                                          canManageVault ||
                                          (isCreator &&
                                              item.creatorId.isNotEmpty);
                                      return _VaultItemTile(
                                        item: item,
                                        canInteractVault: canInteractVault,
                                        canDeleteVault: canDelete,
                                        canEditVisibility: canEditVisibility,
                                        logicalGroups: logicalGroups,
                                      );
                                    }),
                                    if (canCreateVault ||
                                        canManageVault ||
                                        isAdmin)
                                      GhostAddButton(
                                        label: 'Add ${groupType.vaultSingular}',
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                          horizontal: 4,
                                        ),
                                        margin: const EdgeInsets.only(
                                          top: 4,
                                          bottom: 12,
                                        ),
                                        borderRadius: 8,
                                        onTap: () => showDialog(
                                          context: context,
                                          builder: (_) =>
                                              const AddVaultDialog(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              if (hasMore)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: IgnorePointer(
                                    child: Container(
                                      height: 32,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Theme.of(
                                              context,
                                            ).cardColor.withValues(alpha: 0),
                                            Theme.of(context).cardColor,
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.keyboard_arrow_down,
                                          color: Theme.of(context).hintColor,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
          },
          loading: () => const Expanded(child: VaultLoadingSkeleton()),
          error: (e, s) => Expanded(
            child: Text(
              'Error: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: permissionsAsync.when(
        data: (permissions) {
          final canViewVault = PermissionUtils.has(
            permissions,
            PermissionFlags.viewVault,
          );
          if (!canViewVault) {
            return _VaultLockedState(groupType: groupType);
          }
          return content;
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _VaultLockedState(groupType: groupType),
      ),
    );
  }
}

class _VaultLockedState extends StatelessWidget {
  final GroupType groupType;

  const _VaultLockedState({required this.groupType});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            color: Theme.of(context).hintColor,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            '${groupType.vaultTitle} locked',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final String tooltip;

  const _FilterButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isActive
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }
}

class _VaultItemTile extends ConsumerStatefulWidget {
  final VaultItem item;
  final bool canInteractVault;
  final bool canDeleteVault;
  final bool canEditVisibility;
  final List<LogicalGroup> logicalGroups;

  const _VaultItemTile({
    required this.item,
    required this.canInteractVault,
    required this.canDeleteVault,
    required this.canEditVisibility,
    required this.logicalGroups,
  });

  @override
  ConsumerState<_VaultItemTile> createState() => _VaultItemTileState();
}

class _VaultItemTileState extends ConsumerState<_VaultItemTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: widget.canInteractVault
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _isHovering
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: widget.canInteractVault ? _copyToClipboard : null,
                onLongPress: widget.canDeleteVault ? _confirmDelete : null,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Icon(
                      _getIcon(widget.item.type),
                      color: Theme.of(context).colorScheme.tertiary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.item.label,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      _isHovering ? Icons.content_copy : Icons.lock,
                      color: _isHovering
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.canEditVisibility)
                  IconButton(
                    tooltip: 'Edit Visibility',
                    onPressed: _editVisibility,
                    iconSize: 18,
                    splashRadius: 16,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.visibility_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                if (widget.canDeleteVault)
                  IconButton(
                    tooltip: 'Delete Vault Item',
                    onPressed: _confirmDelete,
                    iconSize: 18,
                    splashRadius: 16,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error.withValues(
                        alpha: _isHovering ? 1 : 0.75,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 28, height: 28),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'wifi':
        return Icons.wifi;
      case 'card':
        return Icons.credit_card;
      case 'password':
        return Icons.key;
      default:
        return Icons.lock_outline;
    }
  }

  Future<void> _copyToClipboard() async {
    try {
      final encryption = ref.read(encryptionServiceProvider);
      final syncService = ref.read(syncServiceProvider);
      final roomName = syncService.currentRoomName;

      if (roomName == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active room found!')),
          );
        }
        return;
      }

      final key = await syncService.getVaultKey(roomName);

      final clearTextBytes = await encryption.decrypt(
        base64Decode(widget.item.encryptedValue),
        key,
      );
      final clearText = utf8.decode(clearTextBytes);

      await Clipboard.setData(ClipboardData(text: clearText));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied "${widget.item.label}" to clipboard!'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[VaultWidget] Decryption failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decrypt! (Wrong key?)'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vault Item?'),
        content: Text(
          'Are you sure you want to delete "${widget.item.label}"? This cannot be undone.',
        ),
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

    if (confirm != true) {
      return;
    }

    await ref.read(dashboardRepositoryProvider).deleteVaultItem(widget.item.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${widget.item.label}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editVisibility() async {
    final selected = await showVisibilityGroupSelectorDialog(
      context: context,
      groups: widget.logicalGroups,
      initialSelection: widget.item.visibilityGroupIds,
    );
    if (selected == null) return;

    await ref
        .read(dashboardRepositoryProvider)
        .saveVaultItem(
          widget.item.copyWith(
            visibilityGroupIds: normalizeVisibilityGroupIds(selected),
          ),
        );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Updated vault visibility')));
    }
  }
}

final vaultStreamProvider = StreamProvider<List<VaultItem>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  final myGroupIds = ref.watch(myLogicalGroupIdsProvider);
  final isOwner = ref.watch(currentUserIsOwnerProvider);
  final permissions = ref.watch(currentUserPermissionsProvider).value;
  final bypass =
      isOwner ||
      (permissions != null &&
          PermissionUtils.has(permissions, PermissionFlags.administrator));
  return repo.watchVaultItems().map((items) {
    return items
        .where(
          (item) => canViewByLogicalGroups(
            itemGroupIds: item.visibilityGroupIds,
            viewerGroupIds: myGroupIds,
            bypass: bypass,
          ),
        )
        .toList();
  });
});
