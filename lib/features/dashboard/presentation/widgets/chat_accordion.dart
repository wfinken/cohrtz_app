import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/core/theme/layout_constants.dart';
import 'package:cohortz/core/providers.dart';
import '../providers/unread_message_provider.dart';
import 'chat_widget.dart';
import 'widget_alerts_button.dart';

class ChatAccordion extends ConsumerWidget {
  final String groupName;
  final VoidCallback? onOpenPage;
  final bool isOpen;
  final VoidCallback onToggle;
  final double? maxHeight;

  const ChatAccordion({
    super.key,
    required this.groupName,
    this.onOpenPage,
    required this.isOpen,
    required this.onToggle,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 800;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final groupId =
        ref.watch(syncServiceProvider.select((s) => s.currentRoomName)) ?? '';

    const double headerHeight = LayoutConstants.chatAccordionHeaderHeight;

    final double viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

    // If maxHeight is provided (LayoutBuilder), it likely already accounts for Safe Area and App Bar if they are outside the builder.
    // If using screen height (fallback), we need to subtract those.

    final double contentHeight = isSmallScreen
        ? (maxHeight != null
                  ? (maxHeight! - headerHeight - 20 - viewInsetsBottom)
                  : (size.height -
                        safeAreaTop -
                        kToolbarHeight -
                        headerHeight -
                        20 -
                        viewInsetsBottom))
              .clamp(0.0, double.infinity)
        : (size.height * 0.45) - headerHeight;

    const double borderWidth = LayoutConstants.chatAccordionBorderWidth;

    final double totalHeight = isOpen
        ? (headerHeight + contentHeight + borderWidth)
        : (headerHeight + borderWidth);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      height: totalHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.translucent,
            child: Container(
              height: headerHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.chat_bubble,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final count = ref.watch(totalUnreadCountProvider);
                          if (count == 0 || isOpen) {
                            return const SizedBox.shrink();
                          }
                          return Positioned(
                            right: -6,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                count > 99 ? '99+' : count.toString(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onError,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$groupName Chat',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  WidgetAlertsButton(
                    groupId: groupId,
                    widgetType: 'chat',
                    widgetTitle: 'Chat',
                  ),
                  if (onOpenPage != null)
                    IconButton(
                      icon: Icon(
                        Icons.open_in_full,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      onPressed: onOpenPage,
                      tooltip: 'Expand to full page',
                    ),
                  IconButton(
                    icon: Icon(
                      isOpen
                          ? (isSmallScreen
                                ? Icons.close
                                : Icons.keyboard_arrow_down)
                          : Icons.keyboard_arrow_up,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onToggle,
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: OverflowBox(
              minHeight: contentHeight,
              maxHeight: contentHeight,
              alignment: Alignment.topCenter,
              child: ChatWidget(
                isAccordion: true,
                isOpen: isOpen,
                // Toggle is handled by header, but we keep this for legacy if needed or null it
                onToggleAccordion: null,
                isFullPage: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
