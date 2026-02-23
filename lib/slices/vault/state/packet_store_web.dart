import 'package:flutter/foundation.dart';

import '../models/stored_packet.dart';

class PacketStore extends ChangeNotifier {
  final Map<String, List<StoredPacket>> _packetsByRoom = {};

  Future<void> savePacket(String roomName, StoredPacket packet) async {
    final packets = _packetsByRoom.putIfAbsent(roomName, () => []);
    packets.add(packet);
    notifyListeners();
  }

  Future<List<StoredPacket>> getAllPackets(String roomName) async {
    final packets = _packetsByRoom[roomName];
    if (packets == null) return [];
    return List<StoredPacket>.from(packets);
  }

  Future<int> getStorageSize(String roomName) async {
    final packets = _packetsByRoom[roomName];
    if (packets == null || packets.isEmpty) return 0;

    var totalBytes = 0;
    for (final packet in packets) {
      totalBytes += packet.requestId.length;
      totalBytes += packet.senderId.length;
      totalBytes += packet.payload.length;
      totalBytes += 16;
    }
    return totalBytes;
  }

  Future<List<StoredPacket>> getPacketsForRequest(
    String roomName,
    String requestId,
  ) async {
    final packets = _packetsByRoom[roomName];
    if (packets == null) return [];
    return packets.where((packet) => packet.requestId == requestId).toList();
  }

  Future<void> close() async {
    _packetsByRoom.clear();
  }
}
