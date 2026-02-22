import 'package:cohortz/shared/utils/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/shared/theme/tokens/dialog_button_styles.dart';

import '../../../../app/di/app_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import '../dashboard_edit_notifier.dart';
import '../dialogs/group_settings_dialog.dart';
import 'package:cohortz/slices/members/ui/dialogs/invite_dialog.dart';
import 'package:cohortz/slices/members/ui/dialogs/role_management_dialog.dart';
import 'package:cohortz/slices/members/ui/dialogs/group_user_editor_dialog.dart';
import '../dialogs/app_user_settings_dialog.dart';
import '../dialogs/group_connection_status_dialog.dart';
import 'group_drawer_header.dart';
import 'group_drawer_item.dart';
import 'package:cohortz/slices/chat/ui/providers/unread_message_provider.dart';
import 'package:cohortz/shared/widgets/profile_avatar.dart';

class GroupDrawer extends ConsumerWidget {
  final String groupName;
  final DashboardView currentView;
  final ValueChanged<DashboardView> onViewChanged;
  final VoidCallback? onItemSelected;

  const GroupDrawer({
    super.key,
    required this.groupName,
    required this.currentView,
    required this.onViewChanged,
    this.onItemSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(syncServiceProvider.select((s) => s.identity));
    final profilesAsync = ref.watch(userProfilesProvider);
    final profiles = profilesAsync.value ?? [];

    final isActiveRoomConnected = ref.watch(
      syncServiceProvider.select((s) => s.isActiveRoomConnected),
    );

    final isConnected = isActiveRoomConnected;

    final groupSettingsAsync = ref.watch(groupSettingsProvider);
    final groupType = groupSettingsAsync.value?.groupType ?? GroupType.family;
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    bool canView(int flag) {
      return permissionsAsync.maybeWhen(
        data: (permissions) => PermissionUtils.has(permissions, flag),
        orElse: () => true,
      );
    }

    final canViewVault = canView(PermissionFlags.viewVault);
    final canViewCalendar = canView(PermissionFlags.viewCalendar);
    final canViewTasks = canView(PermissionFlags.viewTasks);
    final canViewNotes = canView(PermissionFlags.viewNotes);
    final canViewMembers = canView(PermissionFlags.viewMembers);
    final canViewChat = canView(PermissionFlags.viewChat);
    final canViewPolls = canView(PermissionFlags.viewPolls);
    final canManageRoles = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.manageRoles),
      orElse: () => false,
    );
    final canManageGroup = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.manageGroup),
      orElse: () => false,
    );
    final canManageInvites = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.manageInvites),
      orElse: () => false,
    );

    var myDisplayName = 'Admin'; // Default fallback
    var myAvatarBase64 = '';
    if (myId != null && profiles.isNotEmpty) {
      final myProfile = profiles.firstWhere(
        (u) => u.id == myId,
        orElse: () => UserProfile(id: '', displayName: 'Admin', publicKey: ''),
      );
      if (myProfile.displayName.isNotEmpty) {
        myDisplayName = myProfile.displayName;
      }
      myAvatarBase64 = myProfile.avatarBase64;
    }

    final isEditing = ref.watch(dashboardEditProvider).isEditing;
    final groupId = ref.read(dashboardRepositoryProvider).currentRoomName ?? '';
    final widgetsAsync = ref.watch(
      dashboardWidgetsProvider((groupId: groupId, columns: 12)),
    );
    final currentWidgets = widgetsAsync.value?.widgets ?? [];

    GroupDrawerItem buildViewItem({
      required IconData icon,
      required String label,
      required DashboardView view,
      int? badgeCount,
    }) {
      return GroupDrawerItem(
        icon: icon,
        label: label,
        isSelected: currentView == view,
        badgeCount: badgeCount,
        onTap: () {
          onViewChanged(view);
          onItemSelected?.call();
        },
      );
    }

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: SafeArea(
        // Fixed: 1
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GroupDrawerHeader(
              groupName: groupName,
              groupDescription: groupSettingsAsync.value?.description ?? '',
              groupAvatarBase64: groupSettingsAsync.value?.avatarBase64 ?? '',
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (isEditing) ...[
                      ...DashboardWidget.allTypes
                          .where(
                            (type) =>
                                !currentWidgets.any((w) => w.type == type) &&
                                (type != 'vault' || canViewVault) &&
                                (type != 'calendar' || canViewCalendar) &&
                                (type != 'polls' || canViewPolls),
                          )
                          .map((type) {
                            IconData icon;
                            switch (type) {
                              case 'calendar':
                                icon = Icons.calendar_today;
                                break;
                              case 'vault':
                                icon = Icons.lock_outline;
                                break;
                              case 'tasks':
                                icon = Icons.checklist;
                                break;
                              case 'notes':
                                icon = Icons.description_outlined;
                                break;
                              case 'polls':
                                icon = Icons.bar_chart;
                                break;
                              case 'users':
                                icon = Icons.people;
                                break;
                              default:
                                icon = Icons.grid_view;
                            }
                            return GroupDrawerItem(
                              icon: icon,
                              label: DashboardWidget.getFriendlyName(type),
                              isSelected: false,
                              onTap: () {
                                ref
                                    .read(dashboardEditProvider.notifier)
                                    .addWidget(type, groupId, 12, 12);
                                onItemSelected?.call();
                              },
                            );
                          }),
                    ] else ...[
                      if (canManageInvites)
                        GroupDrawerItem(
                          icon: Icons.person_add,
                          label: 'Invite',
                          isSelected: false,
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => const InviteDialog(),
                            );
                            onItemSelected?.call();
                          },
                        ),
                      GroupDrawerItem(
                        icon: Icons.grid_view,
                        label: 'Dashboard',
                        isSelected: currentView == DashboardView.dashboard,
                        onTap: () {
                          onViewChanged(DashboardView.dashboard);
                          onItemSelected?.call();
                        },
                      ),
                      if (canViewCalendar)
                        buildViewItem(
                          icon: Icons.calendar_today,
                          label: groupType.calendarTitle.toTitleCase(),
                          view: DashboardView.calendar,
                        ),
                      if (canViewVault)
                        buildViewItem(
                          icon: Icons.lock_outline,
                          label: groupType.vaultTitle.toTitleCase(),
                          view: DashboardView.vault,
                        ),
                      if (canViewTasks)
                        buildViewItem(
                          icon: Icons.checklist,
                          label: groupType.tasksTitle.toTitleCase(),
                          view: DashboardView.tasks,
                        ),
                      if (canViewNotes)
                        buildViewItem(
                          icon: Icons.description_outlined,
                          label: 'Notes',
                          view: DashboardView.notes,
                        ),
                      if (canViewChat)
                        buildViewItem(
                          icon: Icons.chat_bubble_outline,
                          label: 'Channels',
                          view: DashboardView.channels,
                          badgeCount: ref.watch(totalUnreadCountProvider),
                        ),
                      if (canViewPolls)
                        buildViewItem(
                          icon: Icons.bar_chart,
                          label: 'Polls',
                          view: DashboardView.polls,
                        ),
                      if (canViewMembers)
                        buildViewItem(
                          icon: Icons.people,
                          label: 'Members',
                          view: DashboardView.members,
                        ),
                    ],
                  ],
                ),
              ),
            ),

            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GroupDrawerItem(
                  icon: isConnected ? Icons.wifi_tethering : Icons.wifi_off,
                  label: 'Connection Status',
                  isSelected: false,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => const GroupConnectionStatusDialog(),
                    );
                    onItemSelected?.call();
                  },
                ),

                if (canManageInvites)
                  GroupDrawerItem(
                    icon: Icons.person_add,
                    label: 'Invite',
                    isSelected: false,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => const InviteDialog(),
                      );
                      onItemSelected?.call();
                    },
                  ),
                if (canManageRoles)
                  GroupDrawerItem(
                    icon: Icons.shield_outlined,
                    label: 'Roles',
                    isSelected: false,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => const RoleManagementDialog(),
                      );
                      onItemSelected?.call();
                    },
                  ),
                if (canManageGroup)
                  GroupDrawerItem(
                    icon: Icons.settings,
                    label: 'Group Settings',
                    isSelected: false,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => const GroupSettingsDialog(),
                      );
                      onItemSelected?.call();
                    },
                  ),
                GroupDrawerItem(
                  icon: Icons.person_outline,
                  label: 'My Profile',
                  isSelected: false,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => const GroupUserEditorDialog(),
                    );
                    onItemSelected?.call();
                  },
                ),
                GroupDrawerItem(
                  icon: Icons.exit_to_app,
                  label: 'Leave Group',
                  isSelected: false,
                  textColor: Theme.of(context).colorScheme.error,
                  iconColor: Theme.of(context).colorScheme.error,
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Row(
                          children: [
                            Icon(
                              Icons.exit_to_app,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            const Text('Leave Group?'),
                          ],
                        ),
                        content: const Text(
                          'Are you sure you want to leave this group? This will remove your profile from the group list and disconnect you from the mesh.',
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: dialogDestructiveButtonStyle(context),
                            child: const Text('Leave Group'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final syncService = ref.read(syncServiceProvider);
                      final leaveProcess = ref.read(leaveGroupProcessProvider);
                      final roomToLeave = syncService.currentRoomName;
                      if (roomToLeave != null) {
                        await leaveProcess.execute(
                          roomToLeave,
                          localUserId: myId,
                        );
                        if (!context.mounted) return;
                      }
                    }
                  },
                ),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      ProfileAvatar(
                        displayName: myDisplayName,
                        avatarBase64: myAvatarBase64,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          myDisplayName,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.settings,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const AppUserSettingsDialog(),
                          );
                          onItemSelected?.call();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
