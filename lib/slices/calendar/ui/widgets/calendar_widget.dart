import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_gate.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/slices/permissions_core/visibility_acl.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/permissions_feature/state/logical_group_providers.dart';
import 'package:cohortz/shared/widgets/profile_avatar.dart';
import '../dialogs/add_event_dialog.dart';
import '../dialogs/event_details_dialog.dart';
import 'package:cohortz/slices/dashboard_shell/ui/widgets/skeleton_loader.dart';
import 'package:cohortz/slices/dashboard_shell/ui/widgets/ghost_add_button.dart';

class CalendarWidget extends ConsumerWidget {
  const CalendarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final eventsAsync = ref.watch(eventsStreamProvider);
    final profilesAsync = ref.watch(userProfilesProvider);
    final profiles = profilesAsync.value ?? [];
    final settingsAsync = ref.watch(groupSettingsProvider);
    final groupType = settingsAsync.value?.groupType ?? GroupType.family;

    return eventsAsync.when(
      data: (allEvents) {
        final events =
            allEvents.where((e) => e.endTime.isAfter(DateTime.now())).toList()
              ..sort((a, b) => a.time.compareTo(b.time));

        if (events.isEmpty) {
          return PermissionGate(
            permission: PermissionFlags.editCalendar,
            fallback: Text(
              'No ${groupType.calendarTitle.toLowerCase()} yet',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GhostAddButton(
                  label: 'Add ${groupType.calendarSingular}',
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 4,
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  borderRadius: 8,
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const AddEventDialog(),
                  ),
                ),
              ],
            ),
          );
        }

        final hasMore = events.length > 2;

        return Stack(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...events.map((event) {
                      return InkWell(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => EventDetailsDialog(event: event),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.only(
                            right: 12,
                            top: 12,
                            bottom: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: colorScheme.secondary.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _month(event.time),
                                      style: TextStyle(
                                        color: colorScheme.onSecondaryContainer,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      event.time.day.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        color: colorScheme.onSecondaryContainer,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        height: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.title,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_formatTime(event.time)} • ${event.location}',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (event.attendees.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                _buildAttendeeCircles(
                                  context,
                                  event.attendees,
                                  profiles,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                    PermissionGate(
                      permission: PermissionFlags.editCalendar,
                      child: GhostAddButton(
                        label: 'Add ${groupType.calendarSingular}',
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        borderRadius: 8,
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => const AddEventDialog(),
                        ),
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
      loading: () => const CalendarLoadingSkeleton(),
      error: (e, s) => Text(
        'Error: $e',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  String _month(DateTime date) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[date.month - 1];
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  Widget _buildAttendeeCircles(
    BuildContext context,
    Map<String, String> attendees,
    List<UserProfile> profiles,
  ) {
    final goingIds = attendees.entries
        .where((e) => e.value == 'going')
        .map((e) => e.key)
        .take(3) // Show max 3
        .toList();

    if (goingIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 24,
      width: goingIds.length * 18.0 + 6,
      child: Stack(
        children: goingIds.asMap().entries.map((entry) {
          final index = entry.key;
          final userId = entry.value;

          final profile = profiles.firstWhere(
            (p) => p.id == userId,
            orElse: () =>
                UserProfile(id: userId, displayName: '', publicKey: ''),
          );

          return Positioned(
            left: index * 16.0,
            child: ProfileAvatar(
              displayName: profile.displayName,
              avatarBase64: profile.avatarBase64,
              size: 24,
              borderWidth: 2,
              borderColor: Theme.of(context).colorScheme.surface,
            ),
          );
        }).toList(),
      ),
    );
  }
}

final eventsStreamProvider = StreamProvider<List<CalendarEvent>>((ref) {
  final repo = ref.watch(calendarRepositoryProvider);
  final myGroupIds = ref.watch(myLogicalGroupIdsProvider);
  final isOwner = ref.watch(currentUserIsOwnerProvider);
  final permissions = ref.watch(currentUserPermissionsProvider).value;
  final bypass =
      isOwner ||
      (permissions != null &&
          PermissionUtils.has(permissions, PermissionFlags.administrator));

  return repo.watchEvents().map((events) {
    return events
        .where(
          (event) => canViewByLogicalGroups(
            itemGroupIds: event.visibilityGroupIds,
            viewerGroupIds: myGroupIds,
            bypass: bypass,
          ),
        )
        .toList();
  });
});
