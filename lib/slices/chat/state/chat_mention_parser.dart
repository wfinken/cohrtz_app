import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';

class ChatMentionParseResult {
  final List<String> userIds;
  final List<String> roleIds;
  final bool mentionsEveryone;

  const ChatMentionParseResult({
    required this.userIds,
    required this.roleIds,
    required this.mentionsEveryone,
  });
}

class ChatMentionParser {
  static final RegExp _tokenPattern = RegExp(r'(^|\s)@([A-Za-z0-9_.\-]+)');

  const ChatMentionParser();

  ChatMentionParseResult parse({
    required String content,
    required List<UserProfile> users,
    required List<Role> roles,
    required bool canMentionEveryone,
  }) {
    final userByHandle = <String, String>{};
    for (final user in users) {
      final handle = _normalizeHandle(user.displayName);
      if (handle.isEmpty) continue;
      userByHandle[handle] = user.id;
    }

    final roleByHandle = <String, String>{};
    for (final role in roles) {
      final handle = _normalizeHandle(role.name);
      if (handle.isEmpty) continue;
      roleByHandle[handle] = role.id;
    }

    final userIds = <String>{};
    final roleIds = <String>{};
    var everyone = false;

    for (final match in _tokenPattern.allMatches(content)) {
      final tokenRaw = match.group(2) ?? '';
      final token = tokenRaw.trim().toLowerCase();
      if (token.isEmpty) continue;
      if ((token == 'everyone' || token == 'here') && canMentionEveryone) {
        everyone = true;
        continue;
      }
      final userId = userByHandle[token];
      if (userId != null) {
        userIds.add(userId);
        continue;
      }
      final roleId = roleByHandle[token];
      if (roleId != null) {
        roleIds.add(roleId);
      }
    }

    final sortedUsers = userIds.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final sortedRoles = roleIds.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ChatMentionParseResult(
      userIds: sortedUsers,
      roleIds: sortedRoles,
      mentionsEveryone: everyone,
    );
  }

  String _normalizeHandle(String input) {
    final trimmed = input.trim().toLowerCase();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll(RegExp(r'\s+'), '.');
  }
}
