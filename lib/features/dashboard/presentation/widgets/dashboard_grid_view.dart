import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';

import 'package:cohortz/core/permissions/permission_flags.dart';
import 'package:cohortz/core/permissions/permission_providers.dart';
import 'package:cohortz/core/permissions/permission_utils.dart';
import '../../domain/dashboard_models.dart';
import '../../domain/system_model.dart';
import '../../data/dashboard_repository.dart';
import '../dashboard_edit_notifier.dart';

import 'widget_container.dart';
import 'tasks_widget.dart';
import 'calendar_widget.dart';
import 'vault_widget.dart';
import 'chat_widget.dart';
import 'polls_widget.dart';
import 'user_list_widget.dart';
import 'notes_list_widget.dart';

/// A standard grid view for the Dashboard.
///
/// This widget handles:
/// - Displaying widgets in a Bento-style grid using [BentoCollisionResolver].
/// - Drag-and-drop reordering with collision resolution.
/// - Persisting widget positions to local storage.
/// - Adaptive layout for mobile/narrow screens.
class DashboardGridView extends ConsumerStatefulWidget {
  final List<DashboardWidget> widgets;
  final bool requiresScaling;
  final double width;
  final GroupType groupType;
  final bool isEditing;
  final int columns;
  final int layoutIdentifier;

  final ValueChanged<String> onOpenNote;
  final ValueChanged<String> onOpenWidget;

  const DashboardGridView({
    super.key,
    required this.widgets,
    required this.requiresScaling,
    required this.width,
    required this.groupType,
    required this.isEditing,
    required this.columns,
    required this.layoutIdentifier,

    required this.onOpenNote,
    required this.onOpenWidget,
  });

  @override
  ConsumerState<DashboardGridView> createState() => _DashboardGridViewState();
}

class _DashboardGridViewState extends ConsumerState<DashboardGridView> {
  final GlobalKey _gridKey = GlobalKey();
  String? _draggingWidgetId;
  List<DashboardWidget>? _previewWidgets;
  List<DashboardWidget>? _initialWidgets;

  @override
  Widget build(BuildContext context) {
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final canAddByType = permissionsAsync.maybeWhen(
      data: (permissions) => <String, bool>{
        'calendar': PermissionUtils.has(
          permissions,
          PermissionFlags.editCalendar,
        ),
        'vault': PermissionUtils.has(permissions, PermissionFlags.editVault),
        'tasks': PermissionUtils.has(permissions, PermissionFlags.editTasks),
        'polls': PermissionUtils.has(permissions, PermissionFlags.editPolls),
        'users': PermissionUtils.has(
          permissions,
          PermissionFlags.manageInvites,
        ),
      },
      orElse: () => const <String, bool>{},
    );

    final horizontalPadding = 48.0 + (widget.isEditing ? 48.0 : 0.0);
    final availableWidth = widget.width - horizontalPadding;
    const spacing = 24.0;

    final columnWidth =
        ((availableWidth - (widget.columns - 1) * spacing) / widget.columns)
            .floorToDouble();
    const rowHeight = 300.0;

    List<DashboardWidget> displayWidgets;

    if (_previewWidgets != null) {
      displayWidgets = _previewWidgets!;
    } else if (widget.layoutIdentifier == 1) {
      final sortedWidgets = List<DashboardWidget>.from(widget.widgets);
      sortedWidgets.sort((a, b) {
        if (a.y != b.y) return a.y.compareTo(b.y);
        return a.x.compareTo(b.x);
      });

      displayWidgets = [];
      for (int i = 0; i < sortedWidgets.length; i++) {
        final w = sortedWidgets[i];
        displayWidgets.add(
          w.copyWith(x: 0, y: i, width: widget.columns, height: 1),
        );
      }
    } else if (widget.layoutIdentifier == 2) {
      final items = widget.widgets
          .map((w) => w.toGridItem().copyWith(width: 1, height: 1))
          .toList();

      displayWidgets = BentoCollisionResolver.packItems(
        items,
        widget.columns,
      ).map((item) => DashboardWidget.fromGridItem(item)).toList();
    } else {
      final items = widget.widgets
          .map((w) => w.toGridItem().copyWith(height: 1))
          .toList();
      displayWidgets = BentoCollisionResolver.packItems(
        items,
        widget.columns,
      ).map((item) => DashboardWidget.fromGridItem(item)).toList();
    }

    double maxBottom = 0;
    for (var w in displayWidgets) {
      final bottom =
          w.y * rowHeight +
          w.height * rowHeight +
          (w.y + w.height - 1) * spacing;
      if (bottom > maxBottom) maxBottom = bottom;
    }

    return EditModeWorkspace(
      isEditMode: widget.isEditing,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: DragTarget<DashboardWidget>(
          onWillAcceptWithDetails: (details) => true,
          onMove: (details) {
            final renderBox =
                _gridKey.currentContext?.findRenderObject() as RenderBox?;
            if (renderBox == null) return;
            final localPos = renderBox.globalToLocal(details.offset);

            final newX = (localPos.dx / (columnWidth + spacing)).round().clamp(
              0,
              widget.columns -
                  (details.data.width > widget.columns
                      ? widget.columns
                      : details.data.width),
            );
            final newY = (localPos.dy / (rowHeight + spacing)).round().clamp(
              0,
              100,
            );

            if (_previewWidgets == null ||
                details.data.x != newX ||
                details.data.y != newY) {
              var dragged = details.data;
              if (dragged.width > widget.columns) {
                dragged = dragged.copyWith(width: widget.columns);
              }

              var updated = dragged.copyWith(x: newX, y: newY);

              final baseLayout = _initialWidgets ?? displayWidgets;

              final resolvedItems = BentoCollisionResolver.resolveCollisions(
                updated.toGridItem().copyWith(height: 1),
                baseLayout
                    .map((w) => w.toGridItem().copyWith(height: 1))
                    .toList(),
                columns: widget.columns,
              );

              setState(() {
                _previewWidgets = resolvedItems
                    .map((i) => DashboardWidget.fromGridItem(i))
                    .toList();
              });
            }
          },
          onLeave: (_) {
            setState(() {
              _previewWidgets = null;
              _initialWidgets = null;
            });
          },
          onAcceptWithDetails: (details) async {
            if (_previewWidgets != null) {
              final groupId =
                  ref.read(dashboardRepositoryProvider).currentRoomName ?? '';

              await ref
                  .read(localDashboardStorageProvider)
                  .saveWidgets(
                    groupId,
                    _previewWidgets!,
                    columns: widget.layoutIdentifier,
                  );
              ref.invalidate(
                dashboardWidgetsProvider((
                  groupId: groupId,
                  columns: widget.layoutIdentifier,
                )),
              );
            }

            setState(() {
              _previewWidgets = null;
              _initialWidgets = null;
              _draggingWidgetId = null;
            });
          },
          builder: (context, candidateData, rejectedData) {
            return SizedBox(
              key: _gridKey,
              height: maxBottom + (widget.isEditing ? 200 : 0),
              child: Stack(
                children: [
                  ...displayWidgets.map((w) {
                    final left = w.x * (columnWidth + spacing);
                    final top = w.y * (rowHeight + spacing);
                    final width =
                        w.width * columnWidth + (w.width - 1) * spacing;
                    final height =
                        w.height * rowHeight + (w.height - 1) * spacing;

                    return AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      left: left,
                      top: top,
                      width: width,
                      height: height,
                      child: _buildWidgetWrapper(
                        w,
                        widget.groupType,
                        widget.isEditing,
                        canAddByType: canAddByType,
                        colWidth: columnWidth,
                        rowHeight: rowHeight,
                        width: width,
                        height: height,
                        columns: widget.columns,
                        layoutIdentifier: widget.layoutIdentifier,
                        key: ValueKey(w.id),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWidgetWrapper(
    DashboardWidget w,
    GroupType groupType,
    bool isEditing, {
    required Map<String, bool> canAddByType,
    Key? key,
    double colWidth = 0,
    double rowHeight = 0,
    double width = 0,
    double height = 0,
    int columns = 12,
    int layoutIdentifier = 12,
  }) {
    Widget child;
    String title;
    IconData icon;
    Color color;

    switch (w.type) {
      case 'calendar':
        child = const CalendarWidget();
        title = groupType.calendarTitle;
        icon = Icons.calendar_today;
        color = Colors.orange[400]!;
        break;
      case 'vault':
        child = const VaultWidget();
        title = groupType.vaultTitle;
        icon = Icons.security;
        color = Colors.amber[400]!;
        break;
      case 'tasks':
        child = const TasksWidget();
        title = groupType.tasksTitle;
        icon = Icons.checklist;
        color = Colors.purple[400]!;
        break;
      case 'users':
        child = const UserListWidget(isFullPage: false);
        title = 'Members';
        icon = Icons.people;
        color = Colors.teal[400]!;
        break;
      case 'chat':
        child = const ChatWidget();
        title = groupType.chatTitle;
        icon = Icons.chat;
        color = Colors.blue[400]!;
        break;
      case 'polls':
        child = const PollsWidget();
        title = 'Polls';
        icon = Icons.bar_chart;
        color = Colors.indigo[400]!;
        break;
      case 'notes':
        child = NotesListWidget(onOpenNote: widget.onOpenNote);
        title = 'Notes';
        icon = Icons.description_outlined;
        color = Colors.cyan[400]!;
        break;
      default:
        child = const Text('Unknown Widget');
        title = 'Unknown';
        icon = Icons.help;
        color = Colors.grey;
    }

    return LayoutBuilder(
      builder: (context, _) {
        final groupId =
            ref.read(dashboardRepositoryProvider).currentRoomName ?? '';
        return WidgetContainer(
          key: key,
          title: title,
          groupId: groupId,
          iconData: icon,
          iconColor: color,
          isEditing: isEditing,
          expand: true,
          onTitleTap: () => widget.onOpenWidget(w.type),
          onRemove: () => ref
              .read(dashboardEditProvider.notifier)
              .removeWidget(
                w.id,
                ref.read(dashboardRepositoryProvider).currentRoomName ?? '',
                layoutIdentifier,
              ),
          onCycleSize: () => ref
              .read(dashboardEditProvider.notifier)
              .cycleWidgetSize(
                w.id,
                ref.read(dashboardRepositoryProvider).currentRoomName ?? '',
                layoutIdentifier,
                columns,
              ),

          data: w,
          feedbackWidth: width,
          feedbackHeight: height,
          isBeingDragged: w.id == _draggingWidgetId,
          onDragStarted: () {
            setState(() {
              _draggingWidgetId = w.id;
            });
            final groupId =
                ref.read(dashboardRepositoryProvider).currentRoomName ?? '';
            final currentWidgets =
                ref
                    .read(
                      dashboardWidgetsProvider((
                        groupId: groupId,
                        columns: layoutIdentifier,
                      )),
                    )
                    .value
                    ?.widgets ??
                [];
            setState(() {
              _initialWidgets = List.from(currentWidgets);
              final asyncVal = ref.read(
                dashboardWidgetsProvider((
                  groupId: groupId,
                  columns: layoutIdentifier,
                )),
              );
              if (asyncVal.value?.requiresScaling == true &&
                  layoutIdentifier == 1) {
                _initialWidgets = BentoCollisionResolver.adaptToMobile(
                  _initialWidgets!.map((w) => w.toGridItem()).toList(),
                  columns,
                  MediaQuery.of(context).size.width,
                ).map((i) => DashboardWidget.fromGridItem(i)).toList();
              } else if (layoutIdentifier == 2) {
                final items = _initialWidgets!
                    .map((w) => w.toGridItem().copyWith(width: 1, height: 1))
                    .toList();
                _initialWidgets = BentoCollisionResolver.packItems(
                  items,
                  2,
                ).map((i) => DashboardWidget.fromGridItem(i)).toList();
              }
            });
          },
          onDragEnd: () {
            setState(() {
              _draggingWidgetId = null;
              _previewWidgets = null;
              _initialWidgets = null;
            });
          },
          child: child,
        );
      },
    );
  }
}
