import 'dart:convert';

import 'package:cohortz/shared/database/database.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/shared/utils/logging_service.dart';

import 'room_repository_base.dart';

abstract class ICalendarRepository {
  Stream<List<CalendarEvent>> watchEvents();
  Future<void> saveEvent(CalendarEvent event);
  Future<void> deleteEvent(String id);
}

class CalendarRepository extends RoomRepositoryBase
    implements ICalendarRepository {
  const CalendarRepository(super.crdtService, super.roomName);

  @override
  Stream<List<CalendarEvent>> watchEvents() {
    final activeDb = db;
    if (activeDb == null) return Stream.value([]);
    return (activeDb.select(
      activeDb.calendarEvents,
    )..where((t) => t.isDeleted.equals(0))).watch().map((rows) {
      return rows
          .map((row) {
            try {
              return CalendarEventMapper.fromJson(row.value);
            } catch (e) {
              Log.e('[CalendarRepository]', 'Error decoding CalendarEvent', e);
              return null;
            }
          })
          .whereType<CalendarEvent>()
          .toList();
    });
  }

  @override
  Future<void> saveEvent(CalendarEvent event) async {
    final activeDb = db;
    if (activeDb == null) return;
    await activeDb
        .into(activeDb.calendarEvents)
        .insertOnConflictUpdate(
          CalendarEventEntity(
            id: event.id,
            value: jsonEncode(event.toMap()),
            isDeleted: 0,
          ),
        );
  }

  @override
  Future<void> deleteEvent(String id) => crdtDelete(id, 'calendar_events');
}
