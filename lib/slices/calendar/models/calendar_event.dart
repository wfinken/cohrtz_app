import 'package:dart_mappable/dart_mappable.dart';
import 'package:cohortz/slices/permissions_core/acl_group_ids.dart';

part 'calendar_event.mapper.dart';

@MappableClass()
class CalendarEvent with CalendarEventMappable {
  final String id;
  final String title;
  final DateTime time;
  final DateTime endTime;
  final bool isAllDay;
  final bool isRepeating;
  final bool isAllInvited;
  final String location;
  final String description;
  final String creatorId;
  final Map<String, String>
  attendees; // UserId -> Status (going, maybe, not_going)
  final List<String> visibilityGroupIds;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.time,
    required this.endTime,
    this.isAllDay = false,
    this.isRepeating = false,
    this.isAllInvited = false,
    required this.location,
    this.description = '',
    this.creatorId = '',
    this.attendees = const {},
    this.visibilityGroupIds = const [AclGroupIds.everyone],
  });
}
