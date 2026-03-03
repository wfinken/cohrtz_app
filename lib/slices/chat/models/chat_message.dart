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
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? deletedBy;
  final bool isPinned;
  final DateTime? pinnedAt;
  final String? pinnedBy;
  final List<String> mentionUserIds;
  final List<String> mentionRoleIds;
  final List<String> mentionAclGroupIds;
  final bool mentionsEveryone;
  final Map<String, List<String>> reactions;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.threadId = ChatMessage.defaultThreadId,
    required this.content,
    required this.timestamp,
    this.logicalTime = 0,
    this.replyToMessageId,
    this.editedAt,
    this.deletedAt,
    this.deletedBy,
    this.isPinned = false,
    this.pinnedAt,
    this.pinnedBy,
    this.mentionUserIds = const [],
    this.mentionRoleIds = const [],
    this.mentionAclGroupIds = const [],
    this.mentionsEveryone = false,
    this.reactions = const <String, List<String>>{},
  });

  bool get isDeleted => deletedAt != null;
}

@MappableClass()
class ChatThread with ChatThreadMappable {
  static const String channelKind = 'channel';
  static const String dmKind = 'dm';
  static const String subthreadKind = 'subthread';
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
  final String? parentChannelId;
  final String? parentMessageId;
  final DateTime? archivedAt;
  final String? archivedBy;
  final bool isLocked;
  final List<String> memberIds;
  final DateTime? lastActivityAt;

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
    this.parentChannelId,
    this.parentMessageId,
    this.archivedAt,
    this.archivedBy,
    this.isLocked = false,
    this.memberIds = const [],
    this.lastActivityAt,
  });

  bool get isDm => kind == dmKind;
  bool get isChannel => kind == channelKind;
  bool get isSubthread => kind == subthreadKind;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get isArchived => archivedAt != null;
}
