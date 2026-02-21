import 'package:flutter_test/flutter_test.dart';
import 'package:cohortz/src/generated/p2p_packet.pb.dart';

void main() {
  group('P2PPacket Tests', () {
    test('Serialization and Deserialization', () {
      final original = P2PPacket()
        ..type = P2PPacket_PacketType.SYNC_REQ
        ..requestId = 'req-123'
        ..senderId = 'user-a'
        ..payload = [1, 2, 3, 4]
        ..uncompressedSize = 100;

      final buffer = original.writeToBuffer();
      final decoded = P2PPacket.fromBuffer(buffer);

      expect(decoded.type, P2PPacket_PacketType.SYNC_REQ);
      expect(decoded.requestId, 'req-123');
      expect(decoded.senderId, 'user-a');
      expect(decoded.payload, [1, 2, 3, 4]);
      expect(decoded.uncompressedSize, 100);
    });
  });

  // Note: SyncService tests would require mocking LiveKit Room,
  // which implies mocking the platform channel or using a mock library.
  // For this PoC, we are testing the Protobuf logic which is the core data structure.
}
