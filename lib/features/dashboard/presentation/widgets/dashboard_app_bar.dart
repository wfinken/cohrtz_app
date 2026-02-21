import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/user_model.dart';
import '../dashboard_edit_notifier.dart';
import '../dialogs/group_users_dialog.dart';
import '../dialogs/quorum_explanation_dialog.dart';
import 'notification_menu.dart';

/// Dashboard app bar with group controls, mesh status, and user avatars.
///
/// Extracted from dashboard_layout.dart for better modularity.
class DashboardAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  final String title;
  final bool isEditing;
  final bool isDashboardView;
  final ValueChanged<String?>? onActiveGroupChanged;

  const DashboardAppBar({
    super.key,
    required this.title,
    required this.isEditing,
    required this.isDashboardView,
    this.onActiveGroupChanged,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  ConsumerState<DashboardAppBar> createState() => _DashboardAppBarState();
}

class _DashboardAppBarState extends ConsumerState<DashboardAppBar> {
  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncServiceStateProvider);
    final isActiveRoomConnected = syncState.isActiveRoomConnected;
    final isActiveRoomConnecting = syncState.isActiveRoomConnecting;
    final remoteParticipants = syncState.remoteParticipants;

    final isMobile = MediaQuery.of(context).size.width < 600;
    final isConnected = isActiveRoomConnected;
    final profilesAsync = ref.watch(userProfilesProvider);
    final profiles = profilesAsync.value ?? [];

    final onlineCount = isConnected ? 1 + remoteParticipants.length : 0;
    final totalInGroup = profiles.isNotEmpty ? profiles.length : onlineCount;

    final semantic =
        Theme.of(context).extension<AppSemanticColors>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppSemanticColors.dark()
            : AppSemanticColors.light());
    final meshColor = isConnected
        ? semantic.success
        : (isActiveRoomConnecting ? semantic.warning : semantic.danger);

    return AppBar(
      backgroundColor: isMobile
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      shape: isMobile
          ? Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            )
          : null,
      centerTitle: false,
      automaticallyImplyLeading: false,
      titleSpacing: isMobile ? 8 : 16,
      title: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 12),
            Container(
              width: 1,
              height: 24,
              color: Theme.of(context).dividerColor,
            ),
            const SizedBox(width: 12),
            if (isConnected) ...[
              _buildQuorumStatus(context, onlineCount: onlineCount),
              const SizedBox(width: 12),
            ],
          ],
          _buildMeshStatus(
            context,
            isMobile: isMobile,
            isConnected: isConnected,
            isActiveRoomConnecting: isActiveRoomConnecting,
            onlineCount: onlineCount,
            totalInGroup: totalInGroup,
            meshColor: meshColor,
          ),
          if (!isMobile && isConnected) ...[
            const SizedBox(width: 16),
            if (remoteParticipants.isNotEmpty)
              _buildParticipantAvatars(context, remoteParticipants, profiles),
          ],
        ],
      ),
      actions: [
        const NotificationMenu(),
        const SizedBox(width: 8),
        if (isConnected && widget.isDashboardView) ...[
          IconButton(
            icon: Icon(
              widget.isEditing ? Icons.check : Icons.edit_note,
              color: widget.isEditing
                  ? semantic.success
                  : Theme.of(context).hintColor,
            ),
            tooltip: widget.isEditing
                ? 'Done Customizing'
                : 'Customize Dashboard',
            onPressed: () {
              ref.read(dashboardEditProvider.notifier).toggleEditMode();
            },
          ),
          const SizedBox(width: 16),
        ],
      ],
    );
  }

  Widget _buildMeshStatus(
    BuildContext context, {
    required bool isMobile,
    required bool isConnected,
    required bool isActiveRoomConnecting,
    required int onlineCount,
    required int totalInGroup,
    required Color meshColor,
  }) {
    final statusLabel = isConnected
        ? 'Connected'
        : (isActiveRoomConnecting ? 'Connecting' : 'Offline');
    final statusIcon = isActiveRoomConnecting
        ? Icons.sync
        : (isConnected ? Icons.wifi : Icons.wifi_off);

    return GestureDetector(
      onTap: () {
        if (isMobile && isConnected) {
          showDialog(
            context: context,
            builder: (_) => const GroupUsersDialog(),
          );
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusChip(
            label: statusLabel,
            color: meshColor,
            icon: statusIcon,
            semanticLabel:
                'Connection status: $statusLabel. $onlineCount of $totalInGroup online.',
          ),
        ],
      ),
    );
  }

  Widget _buildQuorumStatus(BuildContext context, {required int onlineCount}) {
    final semantic =
        Theme.of(context).extension<AppSemanticColors>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppSemanticColors.dark()
            : AppSemanticColors.light());
    Color getQuorumColor() {
      if (onlineCount <= 1) return semantic.danger;
      if (onlineCount == 2) return semantic.warning;
      return semantic.success;
    }

    final color = getQuorumColor();

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => QuorumExplanationDialog(onlineCount: onlineCount),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusChip(
            label: 'Quorum',
            color: color,
            icon: Icons.storage,
            semanticLabel: 'Quorum status with $onlineCount online members.',
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantAvatars(
    BuildContext context,
    Map<String, RemoteParticipant> remoteParticipants,
    List<UserProfile> profiles,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => const GroupUsersDialog(),
          );
        },
        child: SizedBox(
          height: 32,
          width: remoteParticipants.length * 22.0 + 10,
          child: Stack(
            children: [
              ...List.generate(remoteParticipants.length, (index) {
                final p = remoteParticipants.values.elementAt(index);
                String name = p.identity;
                if (profiles.isNotEmpty) {
                  final profile = profiles.firstWhere(
                    (u) => u.id == p.identity,
                    orElse: () =>
                        UserProfile(id: '', displayName: '', publicKey: ''),
                  );
                  if (profile.displayName.isNotEmpty) {
                    name = profile.displayName;
                  }
                }
                final initials = name.isNotEmpty
                    ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase()
                    : '??';

                return Positioned(
                  left: index * 20.0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
