import 'package:flutter_test/flutter_test.dart';
import 'package:cohortz/features/dashboard/domain/user_model.dart';

void main() {
  group('UserProfile Serialization', () {
    test('toJson returns correct map', () {
      final user = UserProfile(
        id: '12345',
        displayName: 'Test User',
        publicKey: 'pubkey123',
      );

      final json = user.toMap();

      expect(json, {
        'id': '12345',
        'displayName': 'Test User',
        'publicKey': 'pubkey123',
      });
    });

    test('fromJson creates correct object', () {
      final json = {
        'id': '67890',
        'displayName': 'Another User',
        'publicKey': 'key456',
      };

      final user = UserProfileMapper.fromMap(json);

      expect(user.id, '67890');
      expect(user.displayName, 'Another User');
      expect(user.publicKey, 'key456');
    });

    test('round trip serialization works', () {
      final original = UserProfile(
        id: 'abc-def',
        displayName: 'Round Trip',
        publicKey: 'xyz-999',
      );

      final json = original.toMap();
      final copy = UserProfileMapper.fromMap(json);

      expect(copy.id, original.id);
      expect(copy.displayName, original.displayName);
      expect(copy.publicKey, original.publicKey);
    });
  });
}
