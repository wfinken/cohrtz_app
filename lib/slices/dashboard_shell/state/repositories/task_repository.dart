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
    final activeRoom = roomName;
    if (activeDb == null) {
      if (activeRoom == null) return Stream.value([]);
      return crdtService
          .watch(activeRoom, 'SELECT value FROM tasks WHERE is_deleted = 0')
          .map((rows) {
            return rows
                .map((row) {
                  final value = row['value'] as String? ?? '';
                  if (value.isEmpty) return null;
                  try {
                    return TaskItemMapper.fromJson(value);
                  } catch (e) {
                    Log.e('[TaskRepository]', 'Error decoding TaskItem', e);
                    return null;
                  }
                })
                .whereType<TaskItem>()
                .toList();
          });
    }
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
    final activeRoom = roomName;
    if (activeDb == null) {
      if (activeRoom == null) return;
      await crdtService.put(
        activeRoom,
        task.id,
        jsonEncode(task.toMap()),
        tableName: 'tasks',
      );
      return;
    }
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
