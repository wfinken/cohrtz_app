import 'package:flutter_test/flutter_test.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';

void main() {
  group('Profile model backward compatibility', () {
    test('UserProfile defaults bio/avatar when reading legacy json', () {
      final profile = UserProfileMapper.fromJson(
        '{"id":"user:1","displayName":"Alice","publicKey":"abc"}',
      );

      expect(profile.avatarBase64, isEmpty);
      expect(profile.avatarRef, isEmpty);
      expect(profile.bio, isEmpty);
    });

    test(
      'GroupSettings defaults description/avatar when reading legacy json',
      () {
        final settings = GroupSettingsMapper.fromJson(
          '{"id":"group_settings","name":"My Group","createdAt":"2025-01-01T00:00:00.000Z","logicalTime":1,"groupType":"family","dataRoomName":"room-1","ownerId":"user:1","invites":[],"notificationSettingsByUser":{}}',
        );

        expect(settings.description, isEmpty);
        expect(settings.avatarBase64, isEmpty);
        expect(settings.avatarRef, isEmpty);
        expect(settings.name, 'My Group');
      },
    );
  });
}
