import 'package:dart_mappable/dart_mappable.dart';
import 'package:cohortz/slices/permissions_core/acl_group_ids.dart';

part 'task_item.mapper.dart';

@MappableEnum()
enum TaskPriority {
  low,
  regular,
  high;

  String get label => name[0].toUpperCase() + name.substring(1).toLowerCase();
}

@MappableClass()
class TaskSubtask with TaskSubtaskMappable {
  final String title;
  final bool isCompleted;

  TaskSubtask({required this.title, this.isCompleted = false});
}

@MappableClass()
class TaskItem with TaskItemMappable {
  final String id;
  final String title;
  final String assignedTo;
  final String assigneeId;
  final bool isCompleted;
  final TaskPriority priority;
  final String creatorId;
  final DateTime? dueDate;
  final String? dueTime;
  final String? repeat;
  final String? reminder;
  final List<TaskSubtask> subtasks;
  final String? notes;
  final String completedBy;
  final List<String> visibilityGroupIds;

  TaskItem({
    required this.id,
    required this.title,
    required this.assignedTo,
    this.assigneeId = '',
    this.isCompleted = false,
    this.priority = TaskPriority.regular,
    this.creatorId = '',
    this.dueDate,
    this.dueTime,
    this.repeat,
    this.reminder,
    this.subtasks = const [],
    this.notes,
    this.completedBy = '',
    this.visibilityGroupIds = const [AclGroupIds.everyone],
  });
}
