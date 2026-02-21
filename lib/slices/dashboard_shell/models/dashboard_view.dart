import 'package:dart_mappable/dart_mappable.dart';

part 'dashboard_view.mapper.dart';

@MappableEnum()
enum DashboardView {
  dashboard,
  channels,
  vault,
  calendar,
  tasks,
  notes,
  members,
  polls,
}
