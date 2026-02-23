import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:cohortz/app/di/app_providers.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/slices/permissions_feature/state/logical_group_providers.dart';
import 'package:cohortz/slices/permissions_feature/ui/widgets/visibility_group_selector.dart';

class TaskDetailsDialog extends ConsumerStatefulWidget {
  final TaskItem task;

  const TaskDetailsDialog({super.key, required this.task});

  @override
  ConsumerState<TaskDetailsDialog> createState() => _TaskDetailsDialogState();
}

class _TaskDetailsDialogState extends ConsumerState<TaskDetailsDialog> {
  late TaskItem _task;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profiles = ref.watch(userProfilesProvider).value ?? const [];
    final logicalGroups = ref.watch(logicalGroupsProvider);
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final myId = ref.watch(syncServiceProvider.select((s) => s.identity));

    final permissions = permissionsAsync.value ?? PermissionFlags.none;
    final canEditTasks = PermissionUtils.has(
      permissions,
      PermissionFlags.editTasks,
    );
    final canInteractTasks = PermissionUtils.has(
      permissions,
      PermissionFlags.interactTasks,
    );
    final canManageTasks = PermissionUtils.has(
      permissions,
      PermissionFlags.manageTasks,
    );
    final isAdmin = PermissionUtils.has(
      permissions,
      PermissionFlags.administrator,
    );
    final isCreator =
        myId != null && _task.creatorId.isNotEmpty && _task.creatorId == myId;
    final isAssignee =
        myId != null && _task.assigneeId.isNotEmpty && _task.assigneeId == myId;
    final canEditTask =
        isAdmin ||
        isCreator ||
        isAssignee ||
        canEditTasks ||
        canManageTasks ||
        (canInteractTasks && _task.creatorId.isEmpty);

    final creatorLabel = _resolveUserLabel(_task.creatorId, profiles);
    final dueDateLabel = _formatDueDate(_task.dueDate);
    final dueTimeLabel = _formatDueTime(context, _task.dueTime);
    final visibilityLabel = visibilitySelectionSummary(
      selectedGroupIds: _task.visibilityGroupIds,
      allGroups: logicalGroups,
    );

    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _task.title,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(
                    icon: _task.isCompleted
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    label: _task.isCompleted ? 'Completed' : 'Open',
                    foregroundColor: _task.isCompleted
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.primary,
                  ),
                  _StatusChip(
                    icon: Icons.flag_outlined,
                    label: _task.priority.label,
                    foregroundColor: _priorityColor(theme, _task.priority),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                        label: 'Assigned To',
                        value: _task.assignedTo.isEmpty
                            ? 'Unassigned'
                            : _task.assignedTo,
                      ),
                      if (creatorLabel != null)
                        _InfoRow(label: 'Created By', value: creatorLabel),
                      _InfoRow(label: 'Visibility', value: visibilityLabel),
                      if (dueDateLabel != null)
                        _InfoRow(label: 'Due Date', value: dueDateLabel),
                      if (dueTimeLabel != null)
                        _InfoRow(label: 'Due Time', value: dueTimeLabel),
                      if (_task.repeat != null && _task.repeat!.isNotEmpty)
                        _InfoRow(label: 'Repeat', value: _task.repeat!),
                      if (_task.reminder != null && _task.reminder!.isNotEmpty)
                        _InfoRow(label: 'Reminder', value: _task.reminder!),
                      if (_task.notes != null && _task.notes!.trim().isNotEmpty)
                        _NotesSection(notes: _task.notes!.trim()),
                      if (_task.subtasks.isNotEmpty)
                        _SubtasksSection(
                          taskId: _task.id,
                          subtasks: _task.subtasks,
                          canToggle: canEditTask,
                          onToggle: (index) => _toggleSubtask(index),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleSubtask(int index) async {
    if (index < 0 || index >= _task.subtasks.length) return;

    final updatedSubtasks = List<TaskSubtask>.from(_task.subtasks);
    final current = updatedSubtasks[index];
    updatedSubtasks[index] = TaskSubtask(
      title: current.title,
      isCompleted: !current.isCompleted,
    );

    final updatedTask = _task.copyWith(subtasks: updatedSubtasks);

    setState(() {
      _task = updatedTask;
    });

    await ref.read(taskRepositoryProvider).saveTask(updatedTask);
  }

  String? _resolveUserLabel(String userId, List<UserProfile> profiles) {
    if (userId.isEmpty) return null;
    for (final profile in profiles) {
      if (profile.id != userId) continue;
      if (profile.displayName.isNotEmpty) return profile.displayName;
      return profile.id;
    }
    return userId;
  }

  String? _formatDueDate(DateTime? dueDate) {
    if (dueDate == null) return null;
    return DateFormat('EEE, MMM d, y').format(dueDate);
  }

  String? _formatDueTime(BuildContext context, String? dueTime) {
    if (dueTime == null || dueTime.isEmpty) return null;
    final parts = dueTime.split(':');
    if (parts.length != 2) return dueTime;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return dueTime;

    final clampedHour = hour.clamp(0, 23).toInt();
    final clampedMinute = minute.clamp(0, 59).toInt();

    return TimeOfDay(hour: clampedHour, minute: clampedMinute).format(context);
  }

  Color _priorityColor(ThemeData theme, TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return theme.colorScheme.error;
      case TaskPriority.regular:
        return theme.colorScheme.primary;
      case TaskPriority.low:
        return theme.colorScheme.secondary;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foregroundColor;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: foregroundColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: theme.hintColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  final String notes;

  const _NotesSection({required this.notes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NOTES',
              style: TextStyle(
                color: theme.hintColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              notes,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubtasksSection extends StatelessWidget {
  final String taskId;
  final List<TaskSubtask> subtasks;
  final bool canToggle;
  final ValueChanged<int> onToggle;

  const _SubtasksSection({
    required this.taskId,
    required this.subtasks,
    required this.canToggle,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedCount = subtasks.where((s) => s.isCompleted).length;
    final progress = subtasks.isEmpty ? 0.0 : completedCount / subtasks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SUBTASKS',
          style: TextStyle(
            color: theme.hintColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$completedCount/${subtasks.length} completed',
          style: TextStyle(color: theme.hintColor, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 10),
        ...subtasks.asMap().entries.map((entry) {
          final index = entry.key;
          final subtask = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              key: ValueKey('task_dialog_subtask_${taskId}_$index'),
              onTap: canToggle ? () => onToggle(index) : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      subtask.isCompleted
                          ? Icons.check_box_outlined
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: subtask.isCompleted
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        subtask.title,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 13,
                          decoration: subtask.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (!canToggle)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'You do not have permission to edit subtasks.',
              style: TextStyle(color: theme.hintColor, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
