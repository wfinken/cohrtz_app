import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/core/permissions/permission_flags.dart';
import 'package:cohortz/core/permissions/permission_providers.dart';
import 'package:cohortz/core/permissions/permission_utils.dart';
import 'package:cohortz/core/theme/dialog_button_styles.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/user_model.dart';
import '../dialogs/member_roles_dialog.dart';

import 'package:cohortz/features/permissions/data/member_providers.dart';
import '../../../../core/providers.dart';
import '../dialogs/invite_dialog.dart';
import 'ghost_add_button.dart';

class UserListWidget extends ConsumerWidget {
  final bool isFullPage;

  const UserListWidget({super.key, this.isFullPage = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(userProfilesProvider);
    final myId = ref.watch(syncServiceProvider.select((s) => s.identity));
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final settings = ref.watch(groupSettingsProvider).value;

    // Watch the set of connected participant identities for real-time updates
    final connectedIdentities = ref.watch(
      connectedParticipantIdentitiesProvider,
    );

    return profilesAsync.when(
      data: (profiles) {
        if (profiles.isEmpty) {
          return Center(
            child: Text(
              'No members found',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          );
        }

        final canManageMembers = permissionsAsync.maybeWhen(
          data: (permissions) =>
              PermissionUtils.has(permissions, PermissionFlags.manageMembers),
          orElse: () => false,
        );
        final canEditMembers = permissionsAsync.maybeWhen(
          data: (permissions) =>
              PermissionUtils.has(permissions, PermissionFlags.editMembers),
          orElse: () => false,
        );

        Future<void> handleMemberAction({
          required UserProfile profile,
          required bool isBan,
        }) async {
          final actionLabel = isBan ? 'Ban' : 'Kick';
          final reasonController = TextEditingController();
          final banDurations = const [
            _BanDurationOption(label: '1 hour', duration: Duration(hours: 1)),
            _BanDurationOption(
              label: '24 hours',
              duration: Duration(hours: 24),
            ),
            _BanDurationOption(label: '7 days', duration: Duration(days: 7)),
            _BanDurationOption(label: '30 days', duration: Duration(days: 30)),
            _BanDurationOption(label: 'Permanent', duration: null),
          ];
          _BanDurationOption? selectedDuration = isBan ? banDurations[1] : null;

          final result = await showDialog<_MemberActionResult>(
            context: context,
            builder: (context) {
              return StatefulBuilder(
                builder: (context, setState) => AlertDialog(
                  title: Text('$actionLabel Member?'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Add a reason to share with ${profile.displayName.isEmpty ? 'the member' : profile.displayName}.',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Reason (optional)',
                        ),
                      ),
                      if (isBan) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<_BanDurationOption>(
                          initialValue: selectedDuration,
                          decoration: const InputDecoration(
                            labelText: 'Ban duration',
                          ),
                          items: banDurations
                              .map(
                                (option) =>
                                    DropdownMenuItem<_BanDurationOption>(
                                      value: option,
                                      child: Text(option.label),
                                    ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => selectedDuration = value),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'This will remove them from the group.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          _MemberActionResult(
                            reason: reasonController.text.trim(),
                            banDuration: selectedDuration?.duration,
                          ),
                        );
                      },
                      style: dialogDestructiveButtonStyle(context),
                      child: Text(actionLabel),
                    ),
                  ],
                ),
              );
            },
          );

          if (result == null) return;

          await ref.read(memberRepositoryProvider).deleteMember(profile.id);
          await ref
              .read(dashboardRepositoryProvider)
              .deleteUserProfile(profile.id);

          if (context.mounted) {
            final reasonText = result.reason.isEmpty
                ? null
                : 'Reason: ${result.reason}';
            final durationText = isBan
                ? (result.banDuration == null
                      ? 'Duration: Permanent'
                      : 'Duration: ${_formatDuration(result.banDuration!)}')
                : null;
            final details = [
              if (reasonText != null) reasonText,
              if (durationText != null) durationText,
            ].join(' • ');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  [
                    isBan
                        ? 'Banned ${profile.displayName.isEmpty ? 'member' : profile.displayName}.'
                        : 'Kicked ${profile.displayName.isEmpty ? 'member' : profile.displayName}.',
                    if (details.isNotEmpty) details,
                  ].join(' '),
                ),
              ),
            );
          }
        }

        final listPadding = const EdgeInsets.only(bottom: 12);

        return ListView.separated(
          padding: listPadding,
          itemCount: profiles.length + (canEditMembers ? 1 : 0),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index < profiles.length) {
              final profile = profiles[index];
              final isMe = profile.id == myId;
              // Check if this specific user is currently connected
              final isOnline = connectedIdentities.contains(profile.id);
              final isOwner =
                  settings?.ownerId.isNotEmpty == true &&
                  settings?.ownerId == profile.id;
              final showActions =
                  isFullPage && canManageMembers && !isMe && !isOwner;
              return LayoutBuilder(
                builder: (context, constraints) {
                  final isCompactTile = constraints.maxWidth < 280;
                  final avatar = CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Text(
                      profile.displayName.isNotEmpty
                          ? profile.displayName.substring(0, 1).toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                  final statusIcon = Icon(
                    Icons.circle,
                    color: isOnline
                        ? Theme.of(context).colorScheme.tertiary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 12,
                  );

                  final trailing = isCompactTile && showActions
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              tooltip: 'Member actions',
                              icon: const Icon(Icons.more_vert, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                width: 28,
                                height: 28,
                              ),
                              onSelected: (value) {
                                if (value == 'kick') {
                                  handleMemberAction(
                                    profile: profile,
                                    isBan: false,
                                  );
                                } else if (value == 'ban') {
                                  handleMemberAction(
                                    profile: profile,
                                    isBan: true,
                                  );
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'kick',
                                  child: Text('Kick'),
                                ),
                                PopupMenuItem(value: 'ban', child: Text('Ban')),
                              ],
                            ),
                            const SizedBox(width: 4),
                            statusIcon,
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showActions) ...[
                              IconButton(
                                tooltip: 'Kick',
                                icon: const Icon(Icons.person_remove_alt_1),
                                color: Theme.of(context).colorScheme.error,
                                iconSize: 18,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                onPressed: () => handleMemberAction(
                                  profile: profile,
                                  isBan: false,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Ban',
                                icon: const Icon(Icons.block),
                                color: Theme.of(context).colorScheme.error,
                                iconSize: 18,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                onPressed: () => handleMemberAction(
                                  profile: profile,
                                  isBan: true,
                                ),
                              ),
                            ],
                            statusIcon,
                          ],
                        );

                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isCompactTile ? 4 : 0,
                    ),
                    minLeadingWidth: 28,
                    horizontalTitleGap: 8,
                    leading: isCompactTile ? null : avatar,
                    title: isCompactTile
                        ? Row(
                            children: [
                              SizedBox(width: 28, height: 28, child: avatar),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  profile.displayName + (isMe ? ' (You)' : ''),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            profile.displayName + (isMe ? ' (You)' : ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                    subtitle: !isCompactTile && isFullPage && canEditMembers
                        ? Text(
                            'ID: ${profile.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: trailing,
                    onTap: isFullPage
                        ? () {
                            showDialog(
                              context: context,
                              builder: (_) =>
                                  MemberRolesDialog(member: profile),
                            );
                          }
                        : null,
                  );
                },
              );
            }
            return GhostAddButton(
              label: 'Invite Member',
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              borderRadius: 8,
              onTap: () => showDialog(
                context: context,
                builder: (_) => const InviteDialog(),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error loading users: $e')),
    );
  }
}

class _BanDurationOption {
  final String label;
  final Duration? duration;

  const _BanDurationOption({required this.label, required this.duration});
}

class _MemberActionResult {
  final String reason;
  final Duration? banDuration;

  const _MemberActionResult({required this.reason, required this.banDuration});
}

String _formatDuration(Duration duration) {
  if (duration.inDays >= 1) {
    final days = duration.inDays;
    return '$days day${days == 1 ? '' : 's'}';
  }
  if (duration.inHours >= 1) {
    final hours = duration.inHours;
    return '$hours hour${hours == 1 ? '' : 's'}';
  }
  final minutes = duration.inMinutes;
  return '$minutes minute${minutes == 1 ? '' : 's'}';
}
