import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/slices/permissions_core/visibility_acl.dart';
import 'package:cohortz/slices/permissions_feature/state/logical_group_providers.dart';
import 'package:cohortz/slices/permissions_feature/ui/widgets/visibility_group_selector.dart';
import '../../../../app/di/app_providers.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import '../dialogs/add_task_dialog.dart';
import '../dialogs/task_details_dialog.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/dashboard_shell/ui/widgets/skeleton_loader.dart';
import 'package:cohortz/slices/dashboard_shell/ui/widgets/ghost_add_button.dart';

class TasksWidget extends ConsumerWidget {
  const TasksWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(dashboardRepositoryProvider);
    final tasksAsync = ref.watch(tasksStreamProvider);
    final settingsAsync = ref.watch(groupSettingsProvider);
    final groupType = settingsAsync.value?.groupType ?? GroupType.family;
    final logicalGroups = ref.watch(logicalGroupsProvider);
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final canCreateTasks = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.createTasks),
      orElse: () => false,
    );
    final canEditTasks = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.editTasks),
      orElse: () => false,
    );
    final canInteractTasks = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.interactTasks),
      orElse: () => false,
    );
    final canManageTasks = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.manageTasks),
      orElse: () => false,
    );
    final isAdmin = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.administrator),
      orElse: () => false,
    );
    final myId = ref.watch(syncServiceProvider.select((s) => s.identity));

    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          if (!(canCreateTasks || canManageTasks || isAdmin)) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GhostAddButton(
                label: 'Add ${groupType.taskSingular}',
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                margin: const EdgeInsets.symmetric(vertical: 4),
                borderRadius: 8,
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => const AddTaskDialog(),
                ),
              ),
            ],
          );
        }

        final hasMore = tasks.length > 2;

        return Stack(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...tasks.map((task) {
                      final isCreator =
                          myId != null &&
                          task.creatorId.isNotEmpty &&
                          task.creatorId == myId;
                      final isAssignee =
                          myId != null &&
                          task.assigneeId.isNotEmpty &&
                          task.assigneeId == myId;
                      final canEditTask =
                          isAdmin ||
                          isCreator ||
                          isAssignee ||
                          canEditTasks ||
                          canManageTasks ||
                          (canInteractTasks && task.creatorId.isEmpty);
                      final canDeleteTask =
                          (canManageTasks &&
                              (isAdmin ||
                                  isCreator ||
                                  task.creatorId.isEmpty)) ||
                          (isCreator && task.creatorId.isNotEmpty);
                      return InkWell(
                        key: ValueKey('task_tile_${task.id}'),
                        onTap: () => _showTaskDetailsDialog(context, task),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                key: ValueKey('task_checkbox_${task.id}'),
                                onTap: canEditTask
                                    ? () => _toggleTaskCompletion(
                                        repo: repo,
                                        task: task,
                                        myId: myId,
                                      )
                                    : () {},
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: task.isCompleted
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.tertiary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.outline,
                                      ),
                                      color: task.isCompleted
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.tertiary
                                          : null,
                                    ),
                                    child: task.isCompleted
                                        ? const Icon(
                                            Icons.check,
                                            size: 12,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        decoration: task.isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        decorationColor: Theme.of(
                                          context,
                                        ).hintColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Assigned: ${task.assignedTo}',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).hintColor,
                                              fontSize: 10,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getPriorityColor(
                                              context,
                                              task.priority,
                                            ).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: _getPriorityColor(
                                                context,
                                                task.priority,
                                              ).withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Text(
                                            task.priority.label,
                                            style: TextStyle(
                                              color: _getPriorityColor(
                                                context,
                                                task.priority,
                                              ),
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (canEditTask)
                                    IconButton(
                                      key: ValueKey(
                                        'task_visibility_${task.id}',
                                      ),
                                      icon: Icon(
                                        Icons.visibility_outlined,
                                        size: 16,
                                        color: Theme.of(context).hintColor,
                                      ),
                                      onPressed: () async {
                                        final selected =
                                            await showVisibilityGroupSelectorDialog(
                                              context: context,
                                              groups: logicalGroups,
                                              initialSelection:
                                                  task.visibilityGroupIds,
                                            );
                                        if (selected == null) return;
                                        await repo.saveTask(
                                          task.copyWith(
                                            visibilityGroupIds:
                                                normalizeVisibilityGroupIds(
                                                  selected,
                                                ),
                                          ),
                                        );
                                      },
                                      tooltip: 'Edit Visibility',
                                    ),
                                  if (task.isCompleted && canDeleteTask)
                                    IconButton(
                                      key: ValueKey('task_delete_${task.id}'),
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                        color: Theme.of(context).hintColor,
                                      ),
                                      onPressed: () {
                                        repo.deleteTask(task.id);
                                      },
                                      tooltip: 'Delete Task',
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (canCreateTasks || canManageTasks || isAdmin)
                      GhostAddButton(
                        label: 'Add ${groupType.taskSingular}',
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        borderRadius: 8,
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => const AddTaskDialog(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (hasMore)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).cardColor.withValues(alpha: 0),
                          Theme.of(context).cardColor,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Theme.of(context).hintColor,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const TasksLoadingSkeleton(),
      error: (e, s) => Text(
        'Error: $e',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Color _getPriorityColor(BuildContext context, TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Theme.of(context).colorScheme.error;
      case TaskPriority.regular:
        return Theme.of(context).hintColor;
      case TaskPriority.low:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Future<void> _toggleTaskCompletion({
    required DashboardRepository repo,
    required TaskItem task,
    required String? myId,
  }) async {
    await repo.saveTask(
      task.copyWith(
        isCompleted: !task.isCompleted,
        completedBy: !task.isCompleted ? myId ?? '' : '',
      ),
    );
  }

  void _showTaskDetailsDialog(BuildContext context, TaskItem task) {
    showDialog(
      context: context,
      builder: (_) => TaskDetailsDialog(task: task),
    );
  }
}

final tasksStreamProvider = StreamProvider<List<TaskItem>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  final myGroupIds = ref.watch(myLogicalGroupIdsProvider);
  final isOwner = ref.watch(currentUserIsOwnerProvider);
  final permissions = ref.watch(currentUserPermissionsProvider).value;
  final bypass =
      isOwner ||
      (permissions != null &&
          PermissionUtils.has(permissions, PermissionFlags.administrator));

  return repo.watchTasks().map((tasks) {
    return tasks
        .where(
          (task) => canViewByLogicalGroups(
            itemGroupIds: task.visibilityGroupIds,
            viewerGroupIds: myGroupIds,
            bypass: bypass,
          ),
        )
        .toList();
  });
});
