import 'package:flutter/material.dart';
import 'package:cohortz/shared/widgets/profile_avatar.dart';

class GroupDrawerHeader extends StatelessWidget {
  final String groupName;
  final String groupDescription;
  final String groupAvatarBase64;

  const GroupDrawerHeader({
    super.key,
    required this.groupName,
    this.groupDescription = '',
    this.groupAvatarBase64 = '',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ProfileAvatar(
            displayName: groupName,
            avatarBase64: groupAvatarBase64,
            fallbackIcon: Icons.groups_2_outlined,
            size: 38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  groupDescription.trim().isEmpty
                      ? 'COHORT NODE'
                      : groupDescription.trim(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: groupDescription.trim().isEmpty ? 1.0 : 0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
