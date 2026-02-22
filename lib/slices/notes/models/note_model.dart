import 'package:dart_mappable/dart_mappable.dart';
import 'package:cohortz/slices/permissions_core/acl_group_ids.dart';

part 'note_model.mapper.dart';

@MappableClass(caseStyle: CaseStyle.snakeCase)
class Note with NoteMappable {
  final String id;
  final String title;
  final String content;
  final String updatedBy;
  final DateTime updatedAt;
  final int logicalTime;
  final List<String> visibilityGroupIds;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedBy,
    required this.updatedAt,
    this.logicalTime = 0,
    this.visibilityGroupIds = const [AclGroupIds.everyone],
  });
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class NoteEditorPresence with NoteEditorPresenceMappable {
  final String documentId;
  final String userId;
  final String displayName;
  final String colorHex;
  final bool isEditing;
  final DateTime lastSeenAt;
  final int logicalTime;

  const NoteEditorPresence({
    required this.documentId,
    required this.userId,
    required this.displayName,
    required this.colorHex,
    required this.isEditing,
    required this.lastSeenAt,
    this.logicalTime = 0,
  });
}
