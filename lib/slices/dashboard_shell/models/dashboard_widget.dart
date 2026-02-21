import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter_dashboard_grid/flutter_dashboard_grid.dart';

part 'dashboard_widget.mapper.dart';

@MappableClass()
class DashboardWidget with DashboardWidgetMappable {
  final String id;
  final String type; // 'calendar', 'vault', 'tasks', 'chat'
  final int x;
  final int y;
  final int width;
  final int height;

  DashboardWidget({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  static const List<String> allTypes = [
    'calendar',
    'vault',
    'tasks',
    'notes',
    'users',
    'chat',
    'polls',
  ];

  static String getFriendlyName(String type) {
    switch (type) {
      case 'calendar':
        return 'Calendar';
      case 'vault':
        return 'Vault';
      case 'tasks':
        return 'Tasks';
      case 'notes':
        return 'Notes';
      case 'users':
        return 'Members';
      case 'chat':
        return 'Channels';
      case 'polls':
        return 'Polls';
      default:
        if (type.isEmpty) return type;
        return type[0].toUpperCase() + type.substring(1).toLowerCase();
    }
  }

  /// Gets the current BentoSize based on width.
  BentoSize get size => BentoSize.fromColumns(width);

  /// Creates a new DashboardWidget with the width cycled to the next BentoSize.
  DashboardWidget cycleSize() {
    final nextSize = size.next;
    final nextWidth = nextSize.columns;

    int nextX = x;
    if (nextX + nextWidth > 12) {
      nextX = 12 - nextWidth;
    }

    return copyWith(width: nextWidth, x: nextX);
  }

  GridItem toGridItem() {
    return GridItem(
      id: id,
      type: type,
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  static DashboardWidget fromGridItem(GridItem item) {
    return DashboardWidget(
      id: item.id,
      type: item.type,
      x: item.x,
      y: item.y,
      width: item.width,
      height: item.height,
    );
  }
}
