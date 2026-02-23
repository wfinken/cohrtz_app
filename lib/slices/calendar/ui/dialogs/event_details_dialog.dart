import 'package:cohortz/shared/theme/tokens/dialog_button_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';

import '../../../../app/di/app_providers.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/shared/widgets/profile_avatar.dart';
import '../widgets/calendar_widget.dart';
import 'add_event_dialog.dart';

class EventDetailsDialog extends ConsumerWidget {
  final CalendarEvent event;

  const EventDetailsDialog({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Watch for latest event data to be reactive
    final eventsAsync = ref.watch(eventsStreamProvider);
    final latestEvent =
        eventsAsync.value?.firstWhere(
          (e) => e.id == event.id,
          orElse: () => event,
        ) ??
        event;

    final myId = ref.watch(syncServiceProvider.select((s) => s.identity));
    final myStatus = myId != null
        ? (latestEvent.attendees[myId] ?? 'none')
        : 'none';

    final profilesAsync = ref.watch(userProfilesProvider);
    final profiles = profilesAsync.value ?? [];
    final userMap = {for (var p in profiles) p.id: p};

    final creator = userMap[latestEvent.creatorId];
    final creatorName = creator?.displayName ?? 'Unknown';

    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final canInteractCalendar = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.interactCalendar),
      orElse: () => false,
    );
    final canEditCalendar = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.editCalendar),
      orElse: () => false,
    );
    final canManageCalendar = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.manageCalendar),
      orElse: () => false,
    );
    final isAdmin = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.administrator),
      orElse: () => false,
    );
    final isCreator =
        myId != null &&
        latestEvent.creatorId.isNotEmpty &&
        latestEvent.creatorId == myId;

    final canEdit =
        isCreator || canEditCalendar || canManageCalendar || isAdmin;
    final canDelete =
        (canManageCalendar &&
            (isAdmin || isCreator || latestEvent.creatorId.isEmpty)) ||
        (isCreator && latestEvent.creatorId.isNotEmpty);

    final goingList = _getAttendees(latestEvent, 'going', userMap);
    final maybeList = _getAttendees(latestEvent, 'maybe', userMap);
    final notGoingList = _getAttendees(latestEvent, 'not_going', userMap);
    final allAttendees = [...goingList, ...maybeList, ...notGoingList];

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Close Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.onSurface.withValues(
                        alpha: 0.05,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_month,
                        color: theme.colorScheme.onTertiaryContainer,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title and Creator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            latestEvent.title,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (canDelete)
                          IconButton(
                            onPressed: () {}, // Optional menu
                            icon: Icon(Icons.more_vert, color: theme.hintColor),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Created by ',
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          creatorName,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Date & Time
                    _InfoRow(
                      icon: Icons.access_time_filled,
                      title: _formatDateTimeRange(latestEvent),
                      subtitle: latestEvent.isAllDay
                          ? 'All Day'
                          : _formatTimeRange(latestEvent),
                    ),
                    const SizedBox(height: 24),

                    if (latestEvent.isRepeating) ...[
                      _InfoRow(
                        icon: Icons.repeat,
                        title: 'Repeats Daily',
                        subtitle: 'Every day',
                      ),
                      const SizedBox(height: 24),
                    ],
                    const SizedBox(height: 24),

                    // Location
                    _InfoRow(
                      icon: Icons.location_on,
                      title: latestEvent.location,
                      subtitle: 'Location details...', // Can be refined
                    ),
                    const SizedBox(height: 24),

                    // Description
                    if (latestEvent.description.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.05,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '"${latestEvent.description}"',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Attendees
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ATTENDEES',
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 12,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (latestEvent.isAllInvited)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'All Members Invited',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _AttendeeStack(attendees: allAttendees),
                    const SizedBox(height: 32),

                    // RSVP
                    Text(
                      'YOUR RSVP',
                      style: TextStyle(
                        color: theme.hintColor,
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _RsvpToggle(
                      currentStatus: myStatus,
                      onChanged: canInteractCalendar
                          ? (status) =>
                                _updateStatus(context, ref, latestEvent, status)
                          : null,
                    ),
                    const SizedBox(height: 32),

                    // Actions
                    Divider(color: theme.dividerColor),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: canEdit
                                ? () => showDialog(
                                    context: context,
                                    builder: (context) =>
                                        AddEventDialog(event: latestEvent),
                                  )
                                : null,
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            label: const Text('Edit Event'),
                          ),
                        ),
                        if (canDelete) ...[
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () =>
                                _confirmDelete(context, ref, latestEvent),
                            icon: Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.error,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: theme.colorScheme.error
                                  .withValues(alpha: 0.1),
                              padding: const EdgeInsets.all(10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<UserProfile> _getAttendees(
    CalendarEvent event,
    String status,
    Map<String, UserProfile> userMap,
  ) {
    return event.attendees.entries
        .where((e) => e.value == status)
        .map(
          (e) =>
              userMap[e.key] ??
              UserProfile(id: e.key, displayName: 'Unknown', publicKey: ''),
        )
        .toList();
  }

  void _updateStatus(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
    String status,
  ) {
    final myId = ref.read(syncServiceProvider).identity;
    if (myId == null) return;

    final updatedAttendees = Map<String, String>.from(event.attendees);
    updatedAttendees[myId] = status;

    final updatedEvent = event.copyWith(attendees: updatedAttendees);
    ref.read(calendarRepositoryProvider).saveEvent(updatedEvent);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
        title: Text(
          'Delete Event?',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to delete "${event.title}"? This cannot be undone.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: dialogDestructiveButtonStyle(context),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    await ref.read(calendarRepositoryProvider).deleteEvent(event.id);

    if (!context.mounted) {
      return;
    }

    Navigator.pop(context);
  }

  String _formatDateTimeRange(CalendarEvent event) {
    final startRequest = event.time;
    final endRequest = event.endTime;
    final dateFormat = DateFormat('MMM d, y');

    if (event.isAllDay) {
      return dateFormat.format(startRequest);
    }

    if (startRequest.day == endRequest.day &&
        startRequest.month == endRequest.month &&
        startRequest.year == endRequest.year) {
      return dateFormat.format(startRequest);
    } else {
      return '${dateFormat.format(startRequest)} - ${dateFormat.format(endRequest)}';
    }
  }

  String _formatTimeRange(CalendarEvent event) {
    final timeFormat = DateFormat('h:mm a');
    return '${timeFormat.format(event.time)} - ${timeFormat.format(event.endTime)}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.hintColor, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(color: theme.hintColor, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}

class _AttendeeStack extends StatelessWidget {
  final List<UserProfile> attendees;

  const _AttendeeStack({required this.attendees});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (attendees.isEmpty) {
      return Text('No attendees yet', style: TextStyle(color: theme.hintColor));
    }

    const double size = 36;
    const double overlap = 10;
    final displayCount = attendees.length > 5 ? 5 : attendees.length;

    return Row(
      children: [
        SizedBox(
          height: size,
          width: displayCount * (size - overlap) + overlap,
          child: Stack(
            children: List.generate(displayCount, (index) {
              final user = attendees[index];
              return Positioned(
                left: index * (size - overlap),
                child: ProfileAvatar(
                  displayName: user.displayName,
                  avatarBase64: user.avatarBase64,
                  size: size,
                  borderWidth: 2,
                  borderColor: theme.colorScheme.surface,
                ),
              );
            }),
          ),
        ),
        if (attendees.length > 5) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+${attendees.length - 5}',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RsvpToggle extends StatelessWidget {
  final String currentStatus;
  final Function(String)? onChanged;

  const _RsvpToggle({required this.currentStatus, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _RsvpButton(
            label: 'Going',
            icon: Icons.check_circle_outline,
            isSelected: currentStatus == 'going',
            activeColor: colorScheme.tertiary,
            onTap: () => onChanged?.call('going'),
          ),
          _RsvpButton(
            label: 'Maybe',
            icon: Icons.help_outline,
            isSelected: currentStatus == 'maybe',
            activeColor: colorScheme.secondary,
            onTap: () => onChanged?.call('maybe'),
          ),
          _RsvpButton(
            label: 'No',
            icon: Icons.highlight_off,
            isSelected: currentStatus == 'not_going',
            activeColor: colorScheme.error,
            onTap: () => onChanged?.call('not_going'),
          ),
        ],
      ),
    );
  }
}

class _RsvpButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _RsvpButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : theme.hintColor,
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : theme.hintColor,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
