import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';
import '../data/dashboard_repository.dart';
import '../data/local_dashboard_storage.dart';
import '../../dashboard/domain/dashboard_models.dart';

class DashboardEditState {
  final bool isEditing;

  DashboardEditState({this.isEditing = false});

  DashboardEditState copyWith({bool? isEditing}) {
    return DashboardEditState(isEditing: isEditing ?? this.isEditing);
  }
}

class DashboardEditNotifier extends Notifier<DashboardEditState> {
  @override
  DashboardEditState build() => DashboardEditState();

  void toggleEditMode() {
    state = state.copyWith(isEditing: !state.isEditing);
  }

  void setEditMode(bool value) {
    state = state.copyWith(isEditing: value);
  }

  Future<void> cycleWidgetSize(
    String widgetId,
    String groupId,
    int layoutId,
    int gridColumns,
  ) async {
    final storage = ref.read(localDashboardStorageProvider);
    final widgets = await storage.loadWidgets(groupId, columns: layoutId);

    final index = widgets.indexWhere((w) => w.id == widgetId);
    if (index == -1) return;

    final widget = widgets[index];
    final updatedWidget = widget.cycleSize();

    _resolveAndSave(
      updatedWidget,
      widgets,
      groupId,
      layoutId,
      gridColumns,
      storage,
    );
  }

  Future<void> removeWidget(
    String widgetId,
    String groupId,
    int layoutId,
  ) async {
    final storage = ref.read(localDashboardStorageProvider);

    final widgets = await storage.loadWidgets(groupId, columns: layoutId);

    final remaining = widgets
        .where((w) => w.id != widgetId)
        .map((w) => w.toGridItem())
        .toList();

    final compactedItems = BentoCollisionResolver.compactLayout(
      remaining,
      null,
    );

    final resolvedWidgets = compactedItems
        .map((item) => DashboardWidget.fromGridItem(item))
        .toList();

    await storage.saveWidgets(groupId, resolvedWidgets, columns: layoutId);
    ref.invalidate(
      dashboardWidgetsProvider((groupId: groupId, columns: layoutId)),
    );
  }

  Future<void> addWidget(
    String type,
    String groupId,
    int layoutId,
    int gridColumns,
  ) async {
    final storage = ref.read(localDashboardStorageProvider);

    final widgets = await storage.loadWidgets(groupId, columns: layoutId);

    if (widgets.any((w) => w.type == type)) return;

    final newWidget = DashboardWidget(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      x: 0,
      y: 0,
      width: 4,
      height: 1,
    );

    _resolveAndSave(
      newWidget,
      widgets,
      groupId,
      layoutId,
      gridColumns,
      storage,
    );
  }

  Future<void> updatePosition(
    DashboardWidget movedWidget,
    String groupId,
    int layoutId,
    int gridColumns,
  ) async {
    final storage = ref.read(localDashboardStorageProvider);
    final widgets = await storage.loadWidgets(groupId, columns: layoutId);

    _resolveAndSave(
      movedWidget,
      widgets,
      groupId,
      layoutId,
      gridColumns,
      storage,
    );
  }

  Future<void> _resolveAndSave(
    DashboardWidget activeWidget,
    List<DashboardWidget> distinctWidgets,
    String groupId,
    int layoutId,
    int gridColumns,
    LocalDashboardStorage storage,
  ) async {
    final activeItem = activeWidget.toGridItem();
    final baseLayout = distinctWidgets
        .where((w) => w.id != activeWidget.id)
        .map((w) => w.toGridItem())
        .toList();

    final resolvedItems = BentoCollisionResolver.resolveCollisions(
      activeItem,
      baseLayout,
      columns: gridColumns,
    );

    final resolvedWidgets = resolvedItems
        .map((item) => DashboardWidget.fromGridItem(item))
        .toList();

    await storage.saveWidgets(groupId, resolvedWidgets, columns: layoutId);
    ref.invalidate(
      dashboardWidgetsProvider((groupId: groupId, columns: layoutId)),
    );
  }
}

final dashboardEditProvider =
    NotifierProvider<DashboardEditNotifier, DashboardEditState>(
      DashboardEditNotifier.new,
    );
