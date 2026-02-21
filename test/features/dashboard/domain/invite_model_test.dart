import 'package:flutter_test/flutter_test.dart';
import 'package:cohortz/features/dashboard/domain/system_model.dart';

void main() {
  group('GroupInvite Tests', () {
    test('Serialization and Deserialization', () {
      final expiry = DateTime.utc(2025, 12, 31, 12, 0);
      final invite = GroupInvite(
        code: '12345678',
        isSingleUse: true,
        expiresAt: expiry,
      );

      final json = invite.toMap();
      expect(json['code'], '12345678');
      expect(json['isSingleUse'], true);
      expect(json['expiresAt'], expiry.toIso8601String());

      final decoded = GroupInviteMapper.fromMap(json);
      expect(decoded.code, '12345678');
      expect(decoded.isSingleUse, true);
      expect(decoded.expiresAt, expiry);
    });

    test('isValid check', () {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      final future = DateTime.now().add(const Duration(hours: 1));

      expect(GroupInvite(code: 'A', expiresAt: past).isValid, false);
      expect(GroupInvite(code: 'B', expiresAt: future).isValid, true);
      expect(GroupInvite(code: 'C', expiresAt: null).isValid, true);
    });
  });

  group('GroupSettings with Invites Tests', () {
    test('Serialization and Deserialization with Invites', () {
      final invite = GroupInvite(code: 'ABC', isSingleUse: false);
      final settings = GroupSettings(
        id: 'gs-1',
        name: 'Test Group',
        createdAt: DateTime(2025, 1, 1),
        dataRoomName: 'room-1',
        invites: [invite],
      );

      final json = settings.toMap();
      expect(json['invites'], isList);
      expect(json['invites'][0]['code'], 'ABC');

      final decoded = GroupSettingsMapper.fromMap(json);
      expect(decoded.invites.length, 1);
      expect(decoded.invites[0].code, 'ABC');
      expect(decoded.invites[0].isSingleUse, false);
    });
  });
}
