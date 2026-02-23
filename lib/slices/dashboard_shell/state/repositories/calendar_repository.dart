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
    final activeRoom = roomName;
    if (activeDb == null) {
      if (activeRoom == null) return Stream.value([]);
      return crdtService
          .watch(
            activeRoom,
            'SELECT value FROM calendar_events WHERE is_deleted = 0',
          )
          .map((rows) {
            return rows
                .map((row) {
                  final value = row['value'] as String? ?? '';
                  if (value.isEmpty) return null;
                  try {
                    return CalendarEventMapper.fromJson(value);
                  } catch (e) {
                    Log.e(
                      '[CalendarRepository]',
                      'Error decoding CalendarEvent',
                      e,
                    );
                    return null;
                  }
                })
                .whereType<CalendarEvent>()
                .toList();
          });
    }
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
    final activeRoom = roomName;
    if (activeDb == null) {
      if (activeRoom == null) return;
      await crdtService.put(
        activeRoom,
        event.id,
        jsonEncode(event.toMap()),
        tableName: 'calendar_events',
      );
      return;
    }
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
