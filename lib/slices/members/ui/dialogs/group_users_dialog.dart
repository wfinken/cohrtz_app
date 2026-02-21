import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/tokens/dialog_button_styles.dart';
import '../../../../app/di/app_providers.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'group_user_editor_dialog.dart';

class GroupUsersDialog extends ConsumerWidget {
  const GroupUsersDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(syncServiceProvider.select((s) => s.identity));
    final remoteParticipants = ref.watch(
      syncServiceProvider.select((s) => s.remoteParticipants),
    );
    final profilesAsync = ref.watch(userProfilesProvider);
    final allProfiles = profilesAsync.value ?? [];

    final onlineIds = remoteParticipants.keys.toSet();
    if (myId != null) {
      onlineIds.add(myId);
    }
    UserProfile? myProfile;
    if (myId != null && myId.isNotEmpty) {
      for (final profile in allProfiles) {
        if (profile.id == myId) {
          myProfile = profile;
          break;
        }
      }
    }

    final sortedProfiles = List<UserProfile>.from(allProfiles);
    sortedProfiles.sort((a, b) {
      final aOnline = onlineIds.contains(a.id);
      final bOnline = onlineIds.contains(b.id);

      if (aOnline && !bOnline) return -1;
      if (!aOnline && bOnline) return 1;

      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    // If we have no profiles but we are online? (Fallback scenario)

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
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
                    Icons.group,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Group Members',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${onlineIds.length}/${sortedProfiles.length} Online',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit my group profile',
                  onPressed: myId == null || myId.isEmpty
                      ? null
                      : () {
                          showDialog(
                            context: context,
                            builder: (_) => GroupUserEditorDialog(
                              initialProfile: myProfile,
                            ),
                          );
                        },
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (sortedProfiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No members found',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sortedProfiles.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final profile = sortedProfiles[index];
                    final isOnline = onlineIds.contains(profile.id);
                    final isMe = profile.id == myId;

                    final initials = profile.displayName.isNotEmpty
                        ? (profile.displayName.length >= 2
                              ? profile.displayName
                                    .substring(0, 2)
                                    .toUpperCase()
                              : profile.displayName.toUpperCase())
                        : '??';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      leading: Stack(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFF374151),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          if (isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).cardColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              isMe
                                  ? '${profile.displayName} (You)'
                                  : profile.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isOnline
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Theme.of(context).hintColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline
                              ? const Color(0xFF10B981)
                              : Theme.of(context).hintColor,
                        ),
                      ),
                      trailing: (!isOnline && !isMe)
                          ? IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error,
                                size: 20,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Remove User?'),
                                    content: Text(
                                      'Are you sure you want to remove ${profile.displayName} from the list? This cannot be undone.',
                                    ),
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: dialogDestructiveButtonStyle(
                                          context,
                                        ),
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await ref
                                      .read(dashboardRepositoryProvider)
                                      .deleteUserProfile(profile.id);
                                }
                              },
                              tooltip: 'Remove User',
                            )
                          : null,
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
