import 'package:dart_mappable/dart_mappable.dart';
import 'package:cohortz/slices/permissions_core/acl_group_ids.dart';

part 'chat_message.mapper.dart';

@MappableClass()
class ChatMessage with ChatMessageMappable {
  static const String defaultThreadId = 'chat:channel:general';

  final String id;
  final String senderId;
  final String threadId;
  final String content;
  final DateTime timestamp;
  final int logicalTime;
  final String? replyToMessageId;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.threadId = ChatMessage.defaultThreadId,
    required this.content,
    required this.timestamp,
    this.logicalTime = 0,
    this.replyToMessageId,
  });
}

@MappableClass()
class ChatThread with ChatThreadMappable {
  static const String channelKind = 'channel';
  static const String dmKind = 'dm';
  static const String generalId = ChatMessage.defaultThreadId;

  final String id;
  final String kind;
  final String name;
  final List<String> participantIds;
  final String createdBy;
  final DateTime createdAt;
  final int logicalTime;
  final DateTime? expiresAt;
  final List<String> visibilityGroupIds;

  const ChatThread({
    required this.id,
    required this.kind,
    required this.name,
    this.participantIds = const [],
    required this.createdBy,
    required this.createdAt,
    this.logicalTime = 0,
    this.expiresAt,
    this.visibilityGroupIds = const [AclGroupIds.everyone],
  });

  bool get isDm => kind == dmKind;
  bool get isChannel => kind == channelKind;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}
