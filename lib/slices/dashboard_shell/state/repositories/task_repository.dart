import 'dart:convert';

import 'package:cohortz/shared/database/database.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/shared/utils/logging_service.dart';

import 'room_repository_base.dart';

abstract class ITaskRepository {
  Stream<List<TaskItem>> watchTasks();
  Future<void> saveTask(TaskItem task);
  Future<void> deleteTask(String id);
}

class TaskRepository extends RoomRepositoryBase implements ITaskRepository {
  const TaskRepository(super.crdtService, super.roomName);

  @override
  Stream<List<TaskItem>> watchTasks() {
    final activeDb = db;
    if (activeDb == null) return Stream.value([]);
    return (activeDb.select(
      activeDb.tasks,
    )..where((t) => t.isDeleted.equals(0))).watch().map((rows) {
      return rows
          .map((row) {
            try {
              return TaskItemMapper.fromJson(row.value);
            } catch (e) {
              Log.e(
                '[TaskRepository]',
                'Error decoding TaskItem: ${row.value}',
                e,
              );
              return null;
            }
          })
          .whereType<TaskItem>()
          .toList();
    });
  }

  @override
  Future<void> saveTask(TaskItem task) async {
    final activeDb = db;
    if (activeDb == null) return;
    await activeDb
        .into(activeDb.tasks)
        .insertOnConflictUpdate(
          TaskEntity(
            id: task.id,
            value: jsonEncode(task.toMap()),
            isDeleted: 0,
          ),
        );
  }

  @override
  Future<void> deleteTask(String id) => crdtDelete(id, 'tasks');
}
