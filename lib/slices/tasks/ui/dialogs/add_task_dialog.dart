import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../../../slices/permissions_core/permission_flags.dart';
import '../../../../slices/permissions_core/acl_group_ids.dart';
import '../../../../slices/permissions_core/permission_providers.dart';
import '../../../../slices/permissions_core/permission_utils.dart';
import '../../../../slices/permissions_core/visibility_acl.dart';
import '../../../../app/di/app_providers.dart';
import '../../../../shared/theme/tokens/app_theme.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/permissions_feature/models/logical_group_model.dart';
import 'package:cohortz/slices/permissions_feature/state/logical_group_providers.dart';
import 'package:cohortz/slices/permissions_feature/ui/widgets/visibility_group_selector.dart';

class AddTaskDialog extends ConsumerStatefulWidget {
  const AddTaskDialog({super.key});

  @override
  ConsumerState<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends ConsumerState<AddTaskDialog> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final List<TextEditingController> _subtaskControllers = [
    TextEditingController(),
  ];
  final List<bool> _subtaskCompletion = [false];

  String? _selectedAssigneeId;
  TaskPriority _selectedPriority = TaskPriority.regular;
  DateTime? _dueDate = DateTime.now();
  TimeOfDay? _dueTime;
  String _repeat = 'Does not repeat';
  final String _reminder = 'No reminder';
  List<String> _visibilityGroupIds = const [AclGroupIds.everyone];

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    for (final controller in _subtaskControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(userProfilesProvider);
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final logicalGroups = ref.watch(logicalGroupsProvider);
    final permissions = permissionsAsync.value ?? PermissionFlags.none;

    final canCreateTasks = PermissionUtils.has(
      permissions,
      PermissionFlags.createTasks,
    );
    final canManageTasks = PermissionUtils.has(
      permissions,
      PermissionFlags.manageTasks,
    );
    final isAdmin = PermissionUtils.has(
      permissions,
      PermissionFlags.administrator,
    );

    final hasPermission = canCreateTasks || canManageTasks || isAdmin;

    final theme = Theme.of(context);

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      },
      child: Actions(
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _save(hasPermission),
          ),
        },
        child: Focus(
          autofocus: true,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: _buildHeader(hasPermission),
                    ),
                    const SizedBox(height: 20),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTitleInput(hasPermission),
                              const SizedBox(height: 24),
                              _buildAssigneeSection(
                                profilesAsync,
                                hasPermission,
                              ),
                              const SizedBox(height: 24),
                              _buildSchedulePrioritySection(hasPermission),
                              const SizedBox(height: 24),
                              _buildSubtasksSection(hasPermission),
                              const SizedBox(height: 24),
                              _buildNotesSection(hasPermission),
                              const SizedBox(height: 24),
                              _buildVisibilitySection(
                                hasPermission: hasPermission,
                                groups: logicalGroups,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.2)
                            : theme.colorScheme.surfaceContainerLow,
                        border: Border(
                          top: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(AppTheme.dialogRadius),
                        ),
                      ),
                      child: _buildCreateButton(hasPermission),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool hasPermission) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        Text(
          'NEW TASK',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        ElevatedButton(
          onPressed: hasPermission ? () => _save(true) : null,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildTitleInput(bool hasPermission) {
    final theme = Theme.of(context);
    return TextField(
      controller: _titleController,
      enabled: hasPermission,
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        hintText: 'What needs doing?',
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 20,
        ),
        fillColor: theme.colorScheme.surfaceContainerLow,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: true,
      ),
      maxLines: 2,
      minLines: 1,
    );
  }

  Widget _buildAssigneeSection(
    AsyncValue<List<UserProfile>> profilesAsync,
    bool hasPermission,
  ) {
    final theme = Theme.of(context);
    return Column(
      spacing: 12,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: 12,
          children: [
            Icon(
              Icons.people_outline,
              size: 18,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              'ASSIGNED TO',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        profilesAsync.when(
          data: (profiles) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 12,
                children: [
                  _buildAssigneeChip(
                    label: 'Unassigned',
                    isSelected: _selectedAssigneeId == null,
                    onTap: () => setState(() => _selectedAssigneeId = null),
                  ),
                  ...profiles.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildAvatarChip(p),
                    ),
                  ),
                  _buildAddButton(),
                ],
              ),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('Failed to load users'),
        ),
      ],
    );
  }

  Widget _buildAssigneeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarChip(UserProfile profile) {
    final theme = Theme.of(context);
    final isSelected = _selectedAssigneeId == profile.id;
    final initials = profile.displayName.isNotEmpty
        ? profile.displayName[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: () => setState(() => _selectedAssigneeId = profile.id),
      child: CircleAvatar(
        radius: 20,
        backgroundColor: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerLow,
        child: Text(
          initials,
          style: TextStyle(
            color: isSelected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    final theme = Theme.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.onSurfaceVariant),
      ),
      child: Icon(
        Icons.add,
        color: theme.colorScheme.onSurfaceVariant,
        size: 20,
      ),
    );
  }

  Widget _buildSchedulePrioritySection(bool hasPermission) {
    final theme = Theme.of(context);
    return Column(
      spacing: 12,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: 12,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              'SCHEDULE & PRIORITY',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              // Date & Time Row
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildScheduleItem(
                        label: 'DUE DATE',
                        value: _dueDate != null
                            ? DateFormat('MM/dd/yyyy').format(_dueDate!)
                            : 'Set Date',
                        icon: Icons.calendar_today,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => _dueDate = picked);
                        },
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      child: VerticalDivider(
                        color: theme.dividerColor,
                        width: 1,
                      ),
                    ),
                    Expanded(
                      child: _buildScheduleItem(
                        label: 'TIME (OPTIONAL)',
                        value: _dueTime != null
                            ? _dueTime!.format(context)
                            : '-- : -- --',
                        icon: Icons.access_time,
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _dueTime ?? TimeOfDay.now(),
                          );
                          if (picked != null) setState(() => _dueTime = picked);
                        },
                        trailing: _dueTime != null
                            ? IconButton(
                                icon: Icon(
                                  Icons.cancel,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                onPressed: () =>
                                    setState(() => _dueTime = null),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),
              // Repeat & Reminder Row
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: PopupMenuButton<String>(
                        onSelected: (String value) {
                          setState(() => _repeat = value);
                        },
                        color: theme.colorScheme.surfaceContainer,
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'Does not repeat',
                                child: Text(
                                  'Does not repeat',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'Daily',
                                child: Text(
                                  'Daily',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'Weekly',
                                child: Text(
                                  'Weekly',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'Monthly',
                                child: Text(
                                  'Monthly',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'Yearly',
                                child: Text(
                                  'Yearly',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.repeat,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _repeat,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 24,
                      child: VerticalDivider(
                        color: theme.dividerColor,
                        width: 1,
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          // TODO: Implement reminder selection
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _reminder,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),
              // Priority Segmented Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRIORITY',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          _buildPriorityButton(TaskPriority.low),
                          _buildPriorityButton(TaskPriority.regular),
                          _buildPriorityButton(TaskPriority.high),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleItem({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityButton(TaskPriority priority) {
    final theme = Theme.of(context);
    final isSelected = _selectedPriority == priority;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPriority = priority),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            priority.label,
            style: TextStyle(
              color: isSelected
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtasksSection(bool hasPermission) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_box_outlined,
              size: 18,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              'SUBTASKS',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._subtaskControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          final isLast = index == _subtaskControllers.length - 1;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: controller,
              enabled: hasPermission,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: isLast ? 'Add a step...' : null,
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                fillColor: theme.colorScheme.surfaceContainerLow,
                filled: true,
                prefixIcon: IconButton(
                  icon: Icon(
                    isLast
                        ? Icons.add
                        : (_subtaskCompletion[index]
                              ? Icons.check_circle
                              : Icons.circle_outlined),
                    color: isLast
                        ? theme.colorScheme.primary
                        : (_subtaskCompletion[index]
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant),
                    size: 20,
                  ),
                  onPressed: isLast
                      ? null
                      : () {
                          setState(() {
                            _subtaskCompletion[index] =
                                !_subtaskCompletion[index];
                          });
                        },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                suffixIcon: !isLast
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          setState(() {
                            controller.dispose();
                            _subtaskControllers.removeAt(index);
                            _subtaskCompletion.removeAt(index);
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                if (isLast && val.isNotEmpty) {
                  setState(() {
                    _subtaskControllers.add(TextEditingController());
                    _subtaskCompletion.add(false);
                  });
                }
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNotesSection(bool hasPermission) {
    final theme = Theme.of(context);
    return Column(
      spacing: 12,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notes, size: 18, color: theme.colorScheme.onSurface),
            const SizedBox(width: 8),
            Text(
              'NOTES',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        TextField(
          controller: _notesController,
          enabled: hasPermission,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Add notes...',
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            fillColor: theme.colorScheme.surfaceContainerLow,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
            filled: true,
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton(bool hasPermission) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: hasPermission ? () => _save(true) : null,
        child: const Text('CREATE TASK'),
      ),
    );
  }

  Widget _buildVisibilitySection({
    required bool hasPermission,
    required List<LogicalGroup> groups,
  }) {
    final theme = Theme.of(context);
    final summary = visibilitySelectionSummary(
      selectedGroupIds: _visibilityGroupIds,
      allGroups: groups,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VISIBILITY',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: hasPermission,
          title: Text(
            summary,
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          subtitle: const Text('Who can see this task'),
          trailing: const Icon(Icons.chevron_right),
          onTap: !hasPermission
              ? null
              : () async {
                  final selected = await showVisibilityGroupSelectorDialog(
                    context: context,
                    groups: groups,
                    initialSelection: _visibilityGroupIds,
                  );
                  if (selected == null || !mounted) return;
                  setState(
                    () => _visibilityGroupIds = normalizeVisibilityGroupIds(
                      selected,
                    ),
                  );
                },
        ),
      ],
    );
  }

  void _save(bool hasPermission) {
    if (!hasPermission || _titleController.text.isEmpty) return;

    final creatorId = ref.read(syncServiceProvider).identity ?? '';
    final profiles = ref.read(userProfilesProvider).value ?? [];
    final selectedProfile = profiles
        .where((p) => p.id == _selectedAssigneeId)
        .firstOrNull;

    final assignedTo = selectedProfile?.displayName.isEmpty ?? true
        ? (selectedProfile?.id ?? 'Unassigned')
        : selectedProfile!.displayName;

    final task = TaskItem(
      id: 'task:${const Uuid().v4()}',
      title: _titleController.text,
      assignedTo: assignedTo,
      assigneeId: _selectedAssigneeId ?? '',
      isCompleted: false,
      priority: _selectedPriority,
      creatorId: creatorId,
      dueDate: _dueDate,
      dueTime: _dueTime != null
          ? '${_dueTime!.hour}:${_dueTime!.minute}'
          : null,
      repeat: _repeat == 'Does not repeat' ? null : _repeat,
      reminder: _reminder == 'No reminder' ? null : _reminder,
      subtasks: _subtaskControllers
          .asMap()
          .entries
          .where((e) => e.value.text.isNotEmpty)
          .map(
            (e) => TaskSubtask(
              title: e.value.text,
              isCompleted: _subtaskCompletion[e.key],
            ),
          )
          .toList(),
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      visibilityGroupIds: normalizeVisibilityGroupIds(_visibilityGroupIds),
    );

    ref.read(dashboardRepositoryProvider).saveTask(task);
    Navigator.pop(context);
  }
}
