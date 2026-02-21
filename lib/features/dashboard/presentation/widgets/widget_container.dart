import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';

import '../../../../features/dashboard/domain/dashboard_models.dart';
import 'widget_alerts_button.dart';

/// A reusable container widget for dashboard cards that wraps [BentoCard].
class WidgetContainer extends ConsumerStatefulWidget {
  final String title;
  final Widget child;
  final String? groupId;

  final Color? iconColor;
  final IconData? iconData;
  final bool expand;
  final bool isEditing;
  final VoidCallback? onRemove;
  final VoidCallback? onCycleSize;
  final VoidCallback? onTitleTap;

  final DashboardWidget? data;
  final double? feedbackWidth;
  final double? feedbackHeight;
  final bool isBeingDragged;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;

  const WidgetContainer({
    super.key,
    required this.title,
    required this.child,
    this.groupId,

    this.iconColor,
    this.iconData,
    this.expand = false,
    this.isEditing = false,
    this.onRemove,
    this.onCycleSize,
    this.onTitleTap,
    this.data,
    this.feedbackWidth,
    this.feedbackHeight,
    this.isBeingDragged = false,
    this.onDragStarted,
    this.onDragEnd,
  });

  @override
  ConsumerState<WidgetContainer> createState() => _WidgetContainerState();
}

class _WidgetContainerState extends ConsumerState<WidgetContainer> {
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    assert(data != null, 'WidgetContainer requires non-null data.');
    final item = data!.toGridItem();

    Widget cardContent = widget.child;

    if (widget.isBeingDragged) {
      return Opacity(
        opacity: 0.3,
        child: BentoCard(
          item: item,
          isEditMode: false,
          header: _buildHeaderContent(
            context,
            showActions: false,
            showHandle: false,
          ),
          child: cardContent,
        ),
      );
    }

    return BentoCard(
      item: item,
      isEditMode: widget.isEditing,
      showDefaultDragHandle: false,
      onDelete: widget.onRemove,
      onCycleSize: widget.onCycleSize,
      header: _buildHeaderContent(context),
      child: cardContent,
    );
  }

  Widget _buildHeaderContent(
    BuildContext context, {
    bool showActions = true,
    bool showHandle = true,
  }) {
    final enableTitleTap = widget.onTitleTap != null && !widget.isEditing;
    final groupId = widget.groupId ?? '';
    final widgetType = widget.data?.type ?? '';
    final showAlertsAction =
        showActions && !widget.isEditing && widgetType.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: enableTitleTap ? widget.onTitleTap : null,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: (widget.isEditing && showHandle)
                          ? Draggable<DashboardWidget>(
                              data: widget.data,
                              feedback: Material(
                                color: Colors.transparent,
                                elevation: 8,
                                child: SizedBox(
                                  width: widget.feedbackWidth ?? 200,
                                  height: widget.feedbackHeight ?? 100,
                                  child: BentoCard(
                                    item: widget.data!.toGridItem(),
                                    isEditMode: false,
                                    header: _buildHeaderContent(
                                      context,
                                      showActions: false,
                                      showHandle: false, // STOP RECURSION HERE
                                    ),
                                    child: widget.child,
                                  ),
                                ),
                              ),
                              onDragStarted: widget.onDragStarted,
                              onDragEnd: (details) => widget.onDragEnd?.call(),
                              child: const BentoDragIndicator(
                                iconSize: 16,
                                padding: EdgeInsets.all(8),
                                borderRadius: 12,
                              ),
                            )
                          : (!widget.isEditing && widget.iconData != null)
                          ? Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHigh
                                    .withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                widget.iconData,
                                size: 14,
                                color:
                                    widget.iconColor ??
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showAlertsAction) const SizedBox(width: 8),
        if (showAlertsAction)
          WidgetAlertsButton(
            groupId: groupId,
            widgetType: widgetType,
            widgetTitle: widget.title,
          ),
      ],
    );
  }
}
