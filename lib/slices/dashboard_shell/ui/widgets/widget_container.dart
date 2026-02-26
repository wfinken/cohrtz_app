import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';

import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/shared/theme/tokens/app_shape_tokens.dart';
import 'widget_alerts_button.dart';

/// A reusable container widget for dashboard cards.
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
    final shapes = appShapeTokensOf(context);
    final cardRadius = context.appBorderRadius(shapes.cardRadius);
    final data = widget.data;
    assert(data != null, 'WidgetContainer requires non-null data.');

    Widget cardContent = widget.child;

    if (widget.isBeingDragged) {
      return Opacity(
        opacity: 0.3,
        child: _ThemedDashboardCard(
          borderRadius: cardRadius,
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

    return _ThemedDashboardCard(
      borderRadius: cardRadius,
      isEditMode: widget.isEditing,
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
            borderRadius: context.appBorderRadius(6),
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
                                  child: _ThemedDashboardCard(
                                    borderRadius: context.appBorderRadius(
                                      appShapeTokensOf(context).cardRadius,
                                    ),
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
                              child: BentoDragIndicator(
                                iconSize: 16,
                                padding: const EdgeInsets.all(8),
                                borderRadius: context.appRadius(12),
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
                                borderRadius: context.appBorderRadius(10),
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

class _ThemedDashboardCard extends StatefulWidget {
  const _ThemedDashboardCard({
    required this.borderRadius,
    required this.child,
    this.header,
    this.isEditMode = false,
    this.onCycleSize,
    this.onDelete,
  });

  final BorderRadius borderRadius;
  final Widget child;
  final Widget? header;
  final bool isEditMode;
  final VoidCallback? onCycleSize;
  final VoidCallback? onDelete;

  @override
  State<_ThemedDashboardCard> createState() => _ThemedDashboardCardState();
}

class _ThemedDashboardCardState extends State<_ThemedDashboardCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isHovered = _isHovering;
    final isEditMode = widget.isEditMode;

    var mainContent = widget.child;
    if (isEditMode) {
      mainContent = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
        child: mainContent,
      );
      mainContent = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: mainContent,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface.withValues(alpha: 0.98),
              colorScheme.surfaceContainerHigh.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: isHovered ? colorScheme.primary : colorScheme.outlineVariant,
            width: (isHovered && isEditMode) ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.10)
                  : colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 36,
              spreadRadius: 0,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.header != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 12,
                    ),
                    child: widget.header!,
                  ),
                if (widget.header == null) const SizedBox(height: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ClipRRect(
                      borderRadius: _deflateBorderRadius(
                        widget.borderRadius,
                        14,
                      ),
                      child: mainContent,
                    ),
                  ),
                ),
              ],
            ),
            if (isEditMode && isHovered)
              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onCycleSize != null)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.15),
                          borderRadius: context.appBorderRadius(16),
                        ),
                        child: IconButton(
                          onPressed: widget.onCycleSize,
                          icon: Icon(
                            Icons.open_in_full,
                            size: 18,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          padding: const EdgeInsets.all(10),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    if (widget.onDelete != null)
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: context.appBorderRadius(16),
                        ),
                        child: IconButton(
                          onPressed: widget.onDelete,
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: colorScheme.error.withValues(alpha: 0.8),
                          ),
                          padding: const EdgeInsets.all(10),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

BorderRadius _deflateBorderRadius(BorderRadius radius, double amount) {
  double deflate(Radius value) {
    return (value.x - amount).clamp(0.0, double.infinity);
  }

  return BorderRadius.only(
    topLeft: Radius.circular(deflate(radius.topLeft)),
    topRight: Radius.circular(deflate(radius.topRight)),
    bottomLeft: Radius.circular(deflate(radius.bottomLeft)),
    bottomRight: Radius.circular(deflate(radius.bottomRight)),
  );
}
