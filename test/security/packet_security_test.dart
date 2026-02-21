import 'package:flutter_test/flutter_test.dart';
import 'package:cohortz/shared/security/security_service.dart';
import 'package:cohortz/shared/security/encryption_service.dart';
import 'package:cohortz/src/generated/p2p_packet.pb.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Packet Security Tests', () {
    late SecurityService securityService;

    setUp(() async {
      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});

      securityService = SecurityService();
      await securityService.initialize();
    });

    test('Sign and Verify Valid Packet', () async {
      final packet = P2PPacket()
        ..type = P2PPacket_PacketType.DATA_CHUNK
        ..requestId = 'test-req'
        ..senderId = 'user-1'
        ..payload = [1, 2, 3];

      await securityService.signPacket(packet);

      expect(packet.signature, isNotEmpty);
      expect(packet.senderPublicKey, isNotEmpty);

      final isValid = await securityService.verifyPacket(packet);
      expect(isValid, isTrue);
    });

    test('Rejects Tampered Packet (Payload)', () async {
      final packet = P2PPacket()
        ..type = P2PPacket_PacketType.DATA_CHUNK
        ..requestId = 'test-req'
        ..senderId = 'user-1'
        ..payload = [1, 2, 3];

      await securityService.signPacket(packet);

      // Tamper with payload
      packet.payload = [1, 2, 4];

      final isValid = await securityService.verifyPacket(packet);
      expect(isValid, isFalse);
    });

    test('Rejects Tampered Packet (Type)', () async {
      final packet = P2PPacket()
        ..type = P2PPacket_PacketType.DATA_CHUNK
        ..requestId = 'test-req'
        ..senderId = 'user-1'
        ..payload = [1, 2, 3];

      await securityService.signPacket(packet);

      // Tamper with type
      packet.type = P2PPacket_PacketType.SYNC_REQ;

      final isValid = await securityService.verifyPacket(packet);
      expect(isValid, isFalse);
    });

    test('Rejects Packet with Wrong Public Key', () async {
      final packet = P2PPacket()
        ..type = P2PPacket_PacketType.DATA_CHUNK
        ..requestId = 'test-req'
        ..senderId = 'user-1'
        ..payload = [1, 2, 3];

      await securityService.signPacket(packet);

      // Provide a wrong public key for verification
      final wrongPubKey = List<int>.filled(32, 0);
      final isValid = await securityService.verifyPacket(
        packet,
        publicKeyOverride: wrongPubKey,
      );
      expect(isValid, isFalse);
    });

    test('Rejects Unsigned Packet', () async {
      final packet = P2PPacket()
        ..type = P2PPacket_PacketType.DATA_CHUNK
        ..requestId = 'test-req'
        ..senderId = 'user-1'
        ..payload = [1, 2, 3];

      // No signPacket call

      final isValid = await securityService.verifyPacket(packet);
      expect(isValid, isFalse);
    });

    test('GSK Encryption and Decryption', () async {
      final encryptionService = EncryptionService();
      final gsk = await encryptionService.generateKey();

      final payload = [10, 20, 30, 40];
      final encrypted = await encryptionService.encrypt(payload, gsk);
      expect(encrypted, isNot(equals(payload)));

      final decrypted = await encryptionService.decrypt(encrypted, gsk);
      expect(decrypted, equals(payload));
    });
  });
}
