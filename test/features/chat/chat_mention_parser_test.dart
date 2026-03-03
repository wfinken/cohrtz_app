import 'package:flutter_test/flutter_test.dart';
import 'package:cohortz/slices/chat/state/chat_mention_parser.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/permissions_feature/models/logical_group_model.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';

void main() {
  group('ChatMentionParser', () {
    const parser = ChatMentionParser();

    final users = <UserProfile>[
      UserProfile(id: 'u1', displayName: 'Alice Doe', publicKey: 'k1'),
      UserProfile(id: 'u2', displayName: 'Bob', publicKey: 'k2'),
    ];
    final roles = <Role>[
      Role(
        id: 'r1',
        groupId: 'g1',
        name: 'Moderators',
        color: 0,
        position: 1,
        permissions: 0,
      ),
    ];
    final aclGroups = <LogicalGroup>[
      LogicalGroup(id: 'lg1', name: 'Parents', memberIds: const ['u1']),
    ];

    test('extracts user and role mentions', () {
      final result = parser.parse(
        content: 'hey @alice.doe and @moderators',
        users: users,
        roles: roles,
        canMentionEveryone: false,
      );
      expect(result.userIds, contains('u1'));
      expect(result.roleIds, contains('r1'));
      expect(result.mentionsEveryone, isFalse);
    });

    test('gates everyone mentions by permission', () {
      final denied = parser.parse(
        content: 'hello @everyone',
        users: users,
        roles: roles,
        canMentionEveryone: false,
      );
      expect(denied.mentionsEveryone, isFalse);

      final allowed = parser.parse(
        content: 'hello @everyone',
        users: users,
        roles: roles,
        canMentionEveryone: true,
      );
      expect(allowed.mentionsEveryone, isTrue);
    });

    test('extracts ACL group mentions', () {
      final result = parser.parse(
        content: 'hello @parents',
        users: users,
        roles: roles,
        aclGroups: aclGroups,
        canMentionEveryone: false,
      );
      expect(result.aclGroupIds, contains('lg1'));
    });
  });
}
