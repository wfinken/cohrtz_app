import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/di/providers/notification_provider.dart';
import '../../../../slices/notifications/app_notification_service.dart';
import '../../../../shared/theme/tokens/app_shape_tokens.dart';

class NotificationMenu extends ConsumerStatefulWidget {
  const NotificationMenu({super.key});

  @override
  ConsumerState<NotificationMenu> createState() => _NotificationMenuState();
}

class _NotificationMenuState extends ConsumerState<NotificationMenu> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  // Track expanded state for each category. Defaulting to true (expanded) for better UX?
  // Or maybe collapse all by default? Let's default to null (implying expanded) or explicit true.
  final Map<AppNotificationCategory, bool> _expandedCategories = {};

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Transparent barrier to close menu on outside tap
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeMenu,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            width: 360,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: Material(
                elevation: 8,
                color: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    appShapeTokensOf(context).cardRadius,
                  ),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: _NotificationDropdownContent(
                  onClose: _closeMenu,
                  expandedCategories: _expandedCategories,
                  onToggleCategory: (category) {
                    // We need to rebuild the overlay when state changes
                    // Since the state is hoisted here, we can just call setState
                    // But wait, the overlay uses `context` from `builder`.
                    // The `builder` is a closure capturing `this`.
                    // Calling `setState` on `_NotificationMenuState` will rebuild the overlay??
                    // No, OverlayEntry is not automatically rebuilt when parent rebuilds unless passed as child.
                    // We need the content to be responsive.
                    // Actually, modifying `_expandedCategories` and calling `_overlayEntry?.markNeedsBuild()` is the way.
                    setState(() {
                      final current = _expandedCategories[category] ?? true;
                      _expandedCategories[category] = !current;
                    });
                    _overlayEntry?.markNeedsBuild();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(notificationServiceProvider);
    final unreadCount = service.notifications.where((n) => !n.read).length;

    return CompositedTransformTarget(
      link: _layerLink,
      child: IconButton(
        icon: _buildIcon(context, unreadCount),
        onPressed: _toggleMenu,
        tooltip: 'Notifications',
      ),
    );
  }

  Widget _buildIcon(BuildContext context, int unreadCount) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          unreadCount > 0
              ? Icons.notifications_active
              : Icons.notifications_outlined,
          color: unreadCount > 0 ? Theme.of(context).colorScheme.primary : null,
          size: 24,
        ),
        if (unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                unreadCount > 9 ? '9+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationDropdownContent extends ConsumerWidget {
  const _NotificationDropdownContent({
    required this.onClose,
    required this.expandedCategories,
    required this.onToggleCategory,
  });

  final VoidCallback onClose;
  final Map<AppNotificationCategory, bool> expandedCategories;
  final ValueChanged<AppNotificationCategory> onToggleCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(notificationServiceProvider);
    final notifications = service.notifications;
    final unreadCount = notifications.where((n) => !n.read).length;

    if (notifications.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none,
                size: 48,
                color: Theme.of(context).hintColor,
              ),
              const SizedBox(height: 8),
              Text(
                'No notifications',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group notifications by category
    final groupedNotifications =
        <AppNotificationCategory, List<AppNotification>>{};
    for (final notification in notifications) {
      if (!groupedNotifications.containsKey(notification.category)) {
        groupedNotifications[notification.category] = [];
      }
      groupedNotifications[notification.category]!.add(notification);
    }

    // Sort categories (optional logic, could be by most recent notification or fixed order)
    // Let's use fixed order for consistency
    final sortedCategories = AppNotificationCategory.values
        .where((c) => groupedNotifications.containsKey(c))
        .toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(context.appRadius()),
                    ),
                    child: Text(
                      '$unreadCount New',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () {
                    service.clearAll();
                    onClose();
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: sortedCategories.map((category) {
                final categoryNotifications = groupedNotifications[category]!;
                final isExpanded = expandedCategories[category] ?? true;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCategoryHeader(
                      context,
                      service,
                      category,
                      categoryNotifications.length,
                      isExpanded,
                    ),
                    if (isExpanded)
                      ...categoryNotifications.map(
                        (n) => _buildNotificationItem(context, n, service),
                      ),
                    const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(
    BuildContext context,
    AppNotificationService service,
    AppNotificationCategory category,
    int count,
    bool isExpanded,
  ) {
    return InkWell(
      onTap: () => onToggleCategory(category),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              size: 20,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(width: 8),
            Text(
              _getCategoryTitle(category).toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(context.appRadius()),
              ),
              child: Text(
                count.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 24,
              width: 24,
              child: InkWell(
                borderRadius: BorderRadius.circular(context.appRadius()),
                onTap: () => service.clearCategory(category),
                child: const Icon(Icons.close, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    AppNotification notification,
    AppNotificationService service,
  ) {
    // Determine background color based on read status
    final backgroundColor = notification.read
        ? Colors.transparent
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.05);

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: () {
          if (!notification.read) {
            service.markAsRead(notification.id);
          }
          // TODO: Navigate to relevant content if applicable
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(context, notification),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: notification.read
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                  color: notification.read
                                      ? Theme.of(context).hintColor
                                      : null,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(notification.timestamp),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).hintColor,
                                fontSize: 10,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!notification.read)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, AppNotification notification) {
    final (icon, color) = _getIconData(
      Theme.of(context).colorScheme,
      notification.category,
    );
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  (IconData, Color) _getIconData(
    ColorScheme colorScheme,
    AppNotificationCategory category,
  ) {
    switch (category) {
      case AppNotificationCategory.task:
        return (Icons.check_circle_outline, colorScheme.tertiary);
      case AppNotificationCategory.event:
        return (Icons.calendar_today_outlined, colorScheme.secondary);
      case AppNotificationCategory.vault:
        return (Icons.security_outlined, colorScheme.error);
      case AppNotificationCategory.message:
        return (Icons.chat_bubble_outline, colorScheme.primary);
      case AppNotificationCategory.system:
        return (Icons.info_outline, colorScheme.onSurfaceVariant);
    }
  }

  String _getCategoryTitle(AppNotificationCategory category) {
    switch (category) {
      case AppNotificationCategory.task:
        return 'Tasks';
      case AppNotificationCategory.event:
        return 'Events';
      case AppNotificationCategory.vault:
        return 'Vault';
      case AppNotificationCategory.message:
        return 'Messages';
      case AppNotificationCategory.system:
        return 'System';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${timestamp.day}/${timestamp.month}';
  }
}
