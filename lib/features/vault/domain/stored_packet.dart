import 'dart:typed_data';

/// Represents a packet stored in the vault.
///
/// This model is used to persist and retrieve packets from
/// the local packet store database.
class StoredPacket {
  final int? id;
  final String requestId;
  final String senderId;
  final DateTime timestamp;
  final List<int> payload;
  final int packetType;

  StoredPacket({
    this.id,
    required this.requestId,
    required this.senderId,
    required this.timestamp,
    required this.payload,
    required this.packetType,
  });

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'senderId': senderId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'payload': payload is Uint8List ? payload : Uint8List.fromList(payload),
      'packetType': packetType,
    };
  }

  static StoredPacket fromMap(Map<String, dynamic> map) {
    return StoredPacket(
      id: map['id'] as int?,
      requestId: map['requestId'] as String,
      senderId: map['senderId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      payload: map['payload'] as List<int>,
      packetType: map['packetType'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoredPacket &&
          runtimeType == other.runtimeType &&
          requestId == other.requestId &&
          senderId == other.senderId &&
          packetType == other.packetType;

  @override
  int get hashCode =>
      requestId.hashCode ^ senderId.hashCode ^ packetType.hashCode;
}
