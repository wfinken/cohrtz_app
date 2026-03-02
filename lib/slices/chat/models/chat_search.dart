import 'package:dart_mappable/dart_mappable.dart';

import 'chat_message.dart';

part 'chat_search.mapper.dart';

@MappableClass()
class ChatSearchQuery with ChatSearchQueryMappable {
  final String keyword;
  final String? threadId;
  final String? authorId;
  final DateTime? from;
  final DateTime? to;
  final bool hasReply;
  final bool hasMention;

  const ChatSearchQuery({
    required this.keyword,
    this.threadId,
    this.authorId,
    this.from,
    this.to,
    this.hasReply = false,
    this.hasMention = false,
  });
}

@MappableClass()
class ChatSearchResult with ChatSearchResultMappable {
  final ChatMessage message;
  final String snippet;

  const ChatSearchResult({required this.message, required this.snippet});
}
