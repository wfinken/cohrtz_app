import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import '../widgets/calendar_widget.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import '../dialogs/event_details_dialog.dart';
import '../dialogs/add_event_dialog.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsStreamProvider);
    final groupSettingsAsync = ref.watch(groupSettingsProvider);
    final groupType = groupSettingsAsync.value?.groupType ?? GroupType.family;
    final permissionsAsync = ref.watch(currentUserPermissionsProvider);
    final canEditCalendar = permissionsAsync.maybeWhen(
      data: (permissions) =>
          PermissionUtils.has(permissions, PermissionFlags.editCalendar),
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canEditCalendar
          ? FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AddEventDialog(
                    initialDate: _selectedDay ?? DateTime.now(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: Text('Add ${groupType.calendarSingular}'),
            )
          : null,
      body: eventsAsync.when(
        data: (allEvents) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 900;
              final calendarMargin = isMobile
                  ? const EdgeInsets.fromLTRB(16, 16, 16, 8)
                  : const EdgeInsets.all(24);
              final eventsMargin = isMobile
                  ? const EdgeInsets.fromLTRB(16, 8, 16, 16)
                  : const EdgeInsets.fromLTRB(0, 24, 24, 24);

              final calendarPane = Expanded(
                flex: isMobile ? 4 : 3,
                child: Container(
                  margin: calendarMargin,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: TableCalendar<CalendarEvent>(
                    firstDay: DateTime.utc(2020, 10, 16),
                    lastDay: DateTime.utc(2030, 3, 14),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarFormat: _calendarFormat,
                    shouldFillViewport: true,
                    daysOfWeekHeight: 24,
                    eventLoader: (day) {
                      return allEvents.where((event) {
                        return isSameDay(event.time, day);
                      }).toList();
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      if (!isSameDay(_selectedDay, selectedDay)) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      }
                    },
                    onFormatChanged: (format) {
                      if (_calendarFormat != format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      }
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    calendarStyle: CalendarStyle(
                      defaultTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      weekendTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      outsideTextStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      markerDecoration: BoxDecoration(
                        color: Colors.orange[400],
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 17.0,
                        fontWeight: FontWeight.bold,
                      ),
                      leftChevronIcon: Icon(
                        Icons.chevron_left,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      rightChevronIcon: Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              );

              final eventsPane = Expanded(
                flex: isMobile ? 5 : 2,
                child: Container(
                  margin: eventsMargin,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _selectedDay != null
                              ? "${_selectedDay!.month}/${_selectedDay!.day}/${_selectedDay!.year}"
                              : "No Date Selected",
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final selectedDayEvents = _getEventsForDay(
                              allEvents,
                              _selectedDay,
                            );

                            if (selectedDayEvents.isEmpty) {
                              if (!canEditCalendar) {
                                return Center(
                                  child: Text(
                                    'No ${groupType.calendarTitle.toLowerCase()}',
                                    style: TextStyle(
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                                );
                              }
                              return Center(
                                child: TextButton.icon(
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (_) => AddEventDialog(
                                      initialDate:
                                          _selectedDay ?? DateTime.now(),
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.add,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  label: Text(
                                    'Add ${groupType.calendarSingular}',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return ListView(
                              padding: const EdgeInsets.all(16),
                              children: selectedDayEvents.map((event) {
                                return Card(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHigh,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    onTap: () => showDialog(
                                      context: context,
                                      builder: (_) =>
                                          EventDetailsDialog(event: event),
                                    ),
                                    leading: Container(
                                      width: 4,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Colors.orange[400],
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    title: Text(
                                      event.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(_formatTime(event.time)),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );

              if (isMobile) {
                return Column(children: [calendarPane, eventsPane]);
              }

              return Row(children: [calendarPane, eventsPane]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  List<CalendarEvent> _getEventsForDay(
    List<CalendarEvent> allEvents,
    DateTime? day,
  ) {
    if (day == null) return [];
    return allEvents.where((event) => isSameDay(event.time, day)).toList();
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $ampm';
  }
}
