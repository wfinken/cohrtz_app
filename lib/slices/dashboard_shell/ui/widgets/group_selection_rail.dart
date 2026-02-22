import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/app_providers.dart';
import '../dialogs/connection_dialog.dart';
import '../dialogs/app_user_settings_dialog.dart';
import 'group_button.dart';
import 'add_group_button.dart';

/// A Discord-style vertical Group Selection Rail (sidebar) integrated with app state.
///
/// Features:
/// - Fixed 72px width
/// - Theme-integrated colors (no hard-coded values)
/// - Animated group buttons with circle→squircle transform
/// - Scrollable group list
/// - Auto-connects to known groups
/// - Fully responsive to theme changes
class GroupSelectionRail extends ConsumerStatefulWidget {
  final String? activeGroupId;
  final ValueChanged<String>? onGroupSelected;
  final VoidCallback? onToggleDrawer;
  final bool isDrawerOpen;

  const GroupSelectionRail({
    super.key,
    this.activeGroupId,
    this.onGroupSelected,
    this.onToggleDrawer,
    this.isDrawerOpen = false,
  });

  @override
  ConsumerState<GroupSelectionRail> createState() => _GroupSelectionRailState();
}

class _GroupSelectionRailState extends ConsumerState<GroupSelectionRail> {
  @override
  void initState() {
    super.initState();
    // Auto-connect to known groups
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectToKnownGroups();
    });
  }

  Future<void> _connectToKnownGroups() async {
    final syncService = ref.read(syncServiceProvider);
    await syncService.getKnownGroups();
    await syncService.connectAllKnownGroups();
  }

  Future<void> _connectToGroup(Map<String, String?> group) async {
    final syncService = ref.read(syncServiceProvider);
    final roomName = group['roomName'];
    if (roomName != null) {
      syncService.setActiveRoom(roomName);
      widget.onGroupSelected?.call(roomName);
    }
  }

  Future<void> _showAddGroupDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const ConnectionDialog(),
    );
    if (result == true) {
      await _connectToKnownGroups();
    }
  }

  void _showSettingsDialog() {
    showDialog(context: context, builder: (_) => const AppUserSettingsDialog());
  }

  IconData _getGroupIcon(String friendlyName) {
    // Default group icons based on name
    final name = friendlyName.toLowerCase();
    if (name.contains('design')) return Icons.palette;
    if (name.contains('dev') || name.contains('code')) return Icons.code;
    if (name.contains('marketing')) return Icons.campaign;
    if (name.contains('sales')) return Icons.trending_up;
    if (name.contains('family')) return Icons.family_restroom;
    if (name.contains('team')) return Icons.groups;
    return Icons.group; // Default
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final knownGroups = ref.watch(
      syncServiceProvider.select((s) => s.knownGroups),
    );
    final currentRoomName = ref.watch(
      syncServiceProvider.select((s) => s.currentRoomName),
    );

    return Container(
      width: 72,
      color: colorScheme.surface,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Column(
            children: [
              Builder(
                builder: (context) {
                  final hasGroups = knownGroups.isNotEmpty;
                  final isConnected =
                      currentRoomName != null &&
                      ref
                          .read(syncServiceProvider)
                          .isGroupConnected(currentRoomName);
                  final canOpenDrawer = hasGroups && isConnected;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: IconButton(
                        icon: const Icon(Icons.menu),
                        color: canOpenDrawer
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withValues(alpha: 0.38),
                        iconSize: 24,
                        padding: EdgeInsets.zero,
                        onPressed: canOpenDrawer
                            ? () {
                                widget.onToggleDrawer?.call();
                              }
                            : null,
                        tooltip: canOpenDrawer
                            ? 'Expand drawer'
                            : 'Connect to a group first',
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 20,
                ),
                child: Divider(
                  color: colorScheme.outlineVariant,
                  thickness: 1,
                  height: 1,
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: knownGroups.length + 1, // +1 for Add Group button
                  itemBuilder: (context, index) {
                    if (index < knownGroups.length) {
                      final group = knownGroups[index];
                      final roomName = group['roomName'] ?? '';
                      final friendlyName = group['friendlyName'] ?? roomName;
                      final groupAvatarBase64 = group['avatarBase64'] ?? '';
                      final groupDescription = group['description'] ?? '';
                      final isActive = currentRoomName == roomName;
                      final icon = _getGroupIcon(friendlyName);

                      // Get connection status and member count for flyout
                      final isConnected = ref
                          .read(syncServiceProvider)
                          .isGroupConnected(roomName);
                      // Add 1 to include the local user in the count
                      final memberCount =
                          ref
                              .read(syncServiceProvider)
                              .getRemoteParticipantCount(roomName) +
                          1;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GroupButton(
                          label: friendlyName,
                          icon: icon,
                          isActive: isActive,
                          isConnected: isConnected,
                          memberCount: memberCount,
                          avatarBase64: groupAvatarBase64,
                          groupDescription: groupDescription,
                          onTap: () => _connectToGroup(group),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AddGroupButton(onTap: _showAddGroupDialog),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              if (!widget.isDrawerOpen)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: IconButton(
                    icon: const Icon(Icons.settings),
                    color: colorScheme.onSurface,
                    iconSize: 24,
                    onPressed: _showSettingsDialog,
                    tooltip: 'Settings',
                  ),
                ),

              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
