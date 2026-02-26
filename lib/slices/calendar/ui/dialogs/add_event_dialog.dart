import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/acl_group_ids.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/slices/permissions_core/visibility_acl.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/permissions_feature/models/logical_group_model.dart';
import 'package:cohortz/slices/permissions_feature/state/logical_group_providers.dart';
import 'package:cohortz/slices/permissions_feature/ui/widgets/visibility_group_selector.dart';
import '../../../../app/di/app_providers.dart';
import '../../../../shared/theme/tokens/app_shape_tokens.dart';

class AddEventDialog extends ConsumerWidget {
  final DateTime? initialDate;
  final CalendarEvent? event;

  const AddEventDialog({super.key, this.initialDate, this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AddEventDialogContent(initialDate: initialDate, event: event);
  }
}

class _AddEventDialogContent extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final CalendarEvent? event;

  const _AddEventDialogContent({this.initialDate, this.event});

  @override
  ConsumerState<_AddEventDialogContent> createState() =>
      _AddEventDialogContentState();
}

class _AddEventDialogContentState
    extends ConsumerState<_AddEventDialogContent> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  bool _isAllDay = false;
  bool _isRepeating = false;

  bool _isAllInvited = true;
  Set<String> _selectedMemberIds = {};
  List<String> _visibilityGroupIds = const [AclGroupIds.everyone];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title);
    _locationController = TextEditingController(text: widget.event?.location);
    _descriptionController = TextEditingController(
      text: widget.event?.description,
    );

    final start = widget.event?.time ?? widget.initialDate ?? DateTime.now();
    _startDate = start;
    _startTime = TimeOfDay.fromDateTime(start);

    final end = widget.event?.endTime ?? start.add(const Duration(hours: 1));
    _endDate = end;
    _endTime = TimeOfDay.fromDateTime(end);

    _isAllDay = widget.event?.isAllDay ?? false;
    _isRepeating = widget.event?.isRepeating ?? false;

    if (widget.event != null) {
      _isAllInvited = widget.event!.isAllInvited;
      _selectedMemberIds = widget.event!.attendees.keys.toSet();
      _visibilityGroupIds = normalizeVisibilityGroupIds(
        widget.event!.visibilityGroupIds,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.event != null;
    final myId = ref.watch(syncServiceProvider.select((s) => s.identity));
    final isCreator =
        myId != null &&
        widget.event?.creatorId.isNotEmpty == true &&
        widget.event?.creatorId == myId;

    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final permissions = permissionsAsync.value ?? PermissionFlags.none;

    // Watch profiles for invite selection
    final profilesAsync = ref.watch(userProfilesProvider);
    final allProfiles = profilesAsync.value ?? [];
    final logicalGroups = ref.watch(logicalGroupsProvider);

    final isAdmin = PermissionUtils.has(
      permissions,
      PermissionFlags.administrator,
    );
    final canManage = PermissionUtils.has(
      permissions,
      PermissionFlags.manageCalendar,
    );
    final canCreateFlag = PermissionUtils.has(
      permissions,
      PermissionFlags.createCalendar,
    );
    final canEditFlag = PermissionUtils.has(
      permissions,
      PermissionFlags.editCalendar,
    );

    final canAdd = canCreateFlag || canManage || isAdmin;
    final canEdit = isCreator || canEditFlag || canManage || isAdmin;

    final hasPermission = isEditing ? canEdit : canAdd;

    return Dialog(
      backgroundColor:
          theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          appShapeTokensOf(context).cardRadius,
        ),
        side: BorderSide(color: theme.dividerColor),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  Text(
                    isEditing ? 'EDIT EVENT' : 'NEW EVENT',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: hasPermission ? _save : null,
                    child: Text(isEditing ? 'Save' : 'Add'),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Input
                    TextField(
                      // Add some padding to the left
                      controller: _titleController,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Title',
                        hintStyle: TextStyle(
                          color: theme.hintColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.only(left: 8),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Time Section Card
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(
                          context.appRadius(),
                        ),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        children: [
                          // All-day Toggle
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      context.appRadius(),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.access_time,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'All-day',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                                CupertinoSwitch(
                                  value: _isAllDay,
                                  activeTrackColor: theme.colorScheme.primary,
                                  onChanged: (val) {
                                    setState(() => _isAllDay = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: theme.dividerColor),

                          // Start Time
                          _buildDateTimeRow(
                            'Starts',
                            _startDate,
                            _startTime,
                            (date) => setState(() => _startDate = date),
                            (time) => setState(() => _startTime = time),
                          ),

                          if (!_isAllDay) ...[
                            Divider(height: 1, color: theme.dividerColor),

                            // End Time
                            _buildDateTimeRow(
                              'Ends',
                              _endDate,
                              _endTime,
                              (date) => setState(() => _endDate = date),
                              (time) => setState(() => _endTime = time),
                            ),
                          ],

                          Divider(height: 1, color: theme.dividerColor),

                          // Repeat
                          InkWell(
                            onTap: () {
                              setState(() => _isRepeating = !_isRepeating);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(
                                        context.appRadius(),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.repeat,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _isRepeating
                                          ? 'Repeats daily'
                                          : 'Does not repeat',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location Card
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(
                          context.appRadius(),
                        ),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: InkWell(
                        onTap: () {},
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _locationController,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Add Location',
                                    hintStyle: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description Card
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(
                          context.appRadius(),
                        ),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _descriptionController,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        maxLines: null,
                        expands: true,
                        decoration: InputDecoration(
                          hintText: 'Add Description...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          border: InputBorder.none,
                          icon: Icon(
                            Icons.notes,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Invited Card
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(
                          context.appRadius(),
                        ),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: InkWell(
                        onTap: () => _showInviteDialog(context, allProfiles),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.people_outline,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Invited',
                                style: TextStyle(fontSize: 16),
                              ),
                              const Spacer(),
                              Text(
                                _isAllInvited
                                    ? 'All Members'
                                    : '${_selectedMemberIds.length} Members',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildVisibilityTile(
                      hasPermission: hasPermission,
                      groups: logicalGroups,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Create Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.2,
                      )
                    : theme.colorScheme.surfaceContainerLow,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(appShapeTokensOf(context).cardRadius),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: hasPermission ? _save : null,
                  child: Text(isEditing ? 'Save Changes' : 'Create Event'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context, List<UserProfile> allProfiles) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor:
                  theme.dialogTheme.backgroundColor ??
                  theme.colorScheme.surface,
              title: Text(
                'Invite Members',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              content: SizedBox(
                width: 300,
                height: 400,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        'All Members',
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                      value: _isAllInvited,
                      activeThumbColor: theme.colorScheme.primary,
                      onChanged: (val) {
                        setDialogState(() => _isAllInvited = val);
                        setState(() => _isAllInvited = val);
                      },
                    ),
                    Divider(color: theme.dividerColor),
                    Expanded(
                      child: ListView.builder(
                        itemCount: allProfiles.length,
                        itemBuilder: (context, index) {
                          final profile = allProfiles[index];
                          final isSelected = _selectedMemberIds.contains(
                            profile.id,
                          );

                          return CheckboxListTile(
                            title: Text(
                              profile.displayName,
                              style: TextStyle(
                                color: _isAllInvited
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            value: _isAllInvited ? true : isSelected,
                            activeColor: theme.colorScheme.primary,
                            enabled: !_isAllInvited,
                            onChanged: (val) {
                              if (val == true) {
                                _selectedMemberIds.add(profile.id);
                              } else {
                                _selectedMemberIds.remove(profile.id);
                              }
                              setDialogState(() {});
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateTimeRow(
    String label,
    DateTime date,
    TimeOfDay time,
    Function(DateTime) onDateChanged,
    Function(TimeOfDay) onTimeChanged,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ),

          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) onDateChanged(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.appRadius()),
              ),
              child: Text(
                DateFormat.yMMMd().format(date),
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          if (!_isAllDay) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: time,
                );
                if (picked != null) onTimeChanged(picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(context.appRadius()),
                ),
                child: Text(
                  time.format(context),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisibilityTile({
    required bool hasPermission,
    required List<LogicalGroup> groups,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: context.appBorderRadius(),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ListTile(
        enabled: hasPermission,
        leading: Icon(
          Icons.visibility_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: const Text('Visibility'),
        subtitle: Text(
          visibilitySelectionSummary(
            selectedGroupIds: _visibilityGroupIds,
            allGroups: groups,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: !hasPermission
            ? null
            : () async {
                final selected = await showVisibilityGroupSelectorDialog(
                  context: context,
                  groups: groups,
                  initialSelection: _visibilityGroupIds,
                );
                if (selected == null || !mounted) return;
                setState(() {
                  _visibilityGroupIds = normalizeVisibilityGroupIds(selected);
                });
              },
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _isAllDay ? 0 : _startTime.hour,
      _isAllDay ? 0 : _startTime.minute,
    );

    var endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _isAllDay ? 23 : _endTime.hour,
      _isAllDay ? 59 : _endTime.minute,
    );

    if (endDateTime.isBefore(startDateTime)) {
      if (_isAllDay) {
        endDateTime = startDateTime.add(const Duration(hours: 23, minutes: 59));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time')),
        );
        return;
      }
    }

    // If not all invited, use selected IDs. If all invited, we might leave empty,
    // or if we want to be explicit we could add everyone, but easier to use flag.
    // For now we preserve existing statuses if they exist?
    // Simplified: Just rebuild map from selected IDs with default status 'invited'

    Map<String, String> attendees = {};
    if (!_isAllInvited) {
      for (final id in _selectedMemberIds) {
        // preserve existing status if present
        attendees[id] = widget.event?.attendees[id] ?? 'invited';
      }
    } else {
      if (widget.event != null) {
        attendees = Map.from(widget.event!.attendees);
      }
    }

    final event =
        widget.event?.copyWith(
          title: title,
          location: _locationController.text,
          description: _descriptionController.text,
          time: startDateTime,
          endTime: endDateTime,
          isAllDay: _isAllDay,
          isRepeating: _isRepeating,
          isAllInvited: _isAllInvited,
          attendees: attendees,
          visibilityGroupIds: normalizeVisibilityGroupIds(_visibilityGroupIds),
        ) ??
        CalendarEvent(
          id: 'event:${const Uuid().v4()}',
          title: title,
          location: _locationController.text,
          description: _descriptionController.text,
          time: startDateTime,
          endTime: endDateTime,
          isAllDay: _isAllDay,
          isRepeating: _isRepeating,
          isAllInvited: _isAllInvited,
          creatorId: ref.read(syncServiceProvider).identity ?? '',
          attendees: attendees,
          visibilityGroupIds: normalizeVisibilityGroupIds(_visibilityGroupIds),
        );

    await ref.read(calendarRepositoryProvider).saveEvent(event);
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
