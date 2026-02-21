import 'package:flutter/material.dart';

/// A Discord-style flyout that appears when hovering over a group button.
/// Displays the group name, connection status, and member count.
class GroupFlyout extends StatelessWidget {
  final String groupName;
  final bool isConnected;
  final int memberCount;

  const GroupFlyout({
    super.key,
    required this.groupName,
    required this.isConnected,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: colorScheme.surfaceContainerHighest,
      child: Container(
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Name
            Text(
              groupName,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // Connection Status
            Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.pending,
                  size: 16,
                  color: isConnected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected ? 'Connected' : 'Connecting...',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Member Count
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '$memberCount ${memberCount == 1 ? "member" : "members"} online',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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
