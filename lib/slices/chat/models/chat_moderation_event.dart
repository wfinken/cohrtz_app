import 'package:dart_mappable/dart_mappable.dart';

part 'chat_moderation_event.mapper.dart';

@MappableClass()
class ChatModerationEvent with ChatModerationEventMappable {
  final String id;
  final String action;
  final String actorId;
  final String targetUserId;
  final String? threadId;
  final String? messageId;
  final String reason;
  final DateTime timestamp;
  final int logicalTime;
  final Map<String, dynamic> metadata;

  const ChatModerationEvent({
    required this.id,
    required this.action,
    required this.actorId,
    required this.targetUserId,
    this.threadId,
    this.messageId,
    this.reason = '',
    required this.timestamp,
    this.logicalTime = 0,
    this.metadata = const <String, dynamic>{},
  });
}
