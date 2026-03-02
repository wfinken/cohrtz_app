import 'package:dart_mappable/dart_mappable.dart';

part 'chat_presence.mapper.dart';

@MappableClass()
class ChatTypingState with ChatTypingStateMappable {
  final String threadId;
  final String userId;
  final DateTime lastActiveAt;
  final bool isTyping;
  final int logicalTime;

  const ChatTypingState({
    required this.threadId,
    required this.userId,
    required this.lastActiveAt,
    this.isTyping = true,
    this.logicalTime = 0,
  });
}

@MappableClass()
class ChatUserPresence with ChatUserPresenceMappable {
  final String userId;
  final String state;
  final DateTime lastSeenAt;
  final int logicalTime;

  const ChatUserPresence({
    required this.userId,
    required this.state,
    required this.lastSeenAt,
    this.logicalTime = 0,
  });

  bool get isOnline => state == 'online';
  bool get isIdle => state == 'idle';
  bool get isOffline => state == 'offline';
}
