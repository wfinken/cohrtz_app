import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:cohortz/src/generated/p2p_packet.pb.dart';
import '../../../shared/utils/logging_service.dart';
import '../../../shared/security/security_service.dart';

/// Handles peer handshake and key exchange operations.
///
/// Key exchange is the foundation of E2EE - peers must exchange public keys
/// before they can communicate securely.
class HandshakeHandler {
  final SecurityService _securityService;
  final String Function(String roomName) getLocalParticipantIdForRoom;
  final Future<void> Function(String roomName, P2PPacket packet) broadcast;

  /// Signing public keys by room -> sender ID
  final Map<String, Map<String, List<int>>> _knownPublicKeysByRoom = {};

  /// X25519 encryption public keys by room -> sender ID
  final Map<String, Map<String, List<int>>> _knownEncryptionKeysByRoom = {};

  /// Packets waiting for sender's key before processing (room -> sender -> packets)
  final Map<String, Map<String, List<P2PPacket>>> _pendingPacketsByRoom = {};

  final Map<String, DateTime> _lastBroadcastTime = {};
  final Map<String, DateTime> _lastRequestTime = {};

  HandshakeHandler({
    required SecurityService securityService,
    required this.getLocalParticipantIdForRoom,
    required this.broadcast,
  }) : _securityService = securityService;

  /// Broadcasts our public keys to peers in a room.
  Future<void> broadcastHandshake(
    String roomName, {
    List<int>? treeKemPubKey,
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force) {
      final last = _lastBroadcastTime[roomName];
      if (last != null && now.difference(last) < const Duration(seconds: 5)) {
        return;
      }
    }
    _lastBroadcastTime[roomName] = now;

    Log.d('HandshakeHandler', 'Broadcasting HANDSHAKE for $roomName...');

    // Generate and broadcast keys scoped to this room/group.
    final pubKey = await _securityService.getPublicKey(groupId: roomName);
    final encPubKey = await _securityService.getEncryptionPublicKey(
      groupId: roomName,
    );

    final packet = P2PPacket()
      ..type = P2PPacket_PacketType.HANDSHAKE
      ..requestId = const Uuid().v4()
      ..senderId = getLocalParticipantIdForRoom(roomName)
      ..payload = pubKey
      ..encryptionPublicKey = encPubKey;

    if (treeKemPubKey != null) {
      packet.senderPublicKey = treeKemPubKey;
    }

    await broadcast(roomName, packet);
  }

  /// Requests handshakes from other peers (empty payload = request).
  Future<void> requestHandshake(String roomName, {bool force = false}) async {
    final now = DateTime.now();
    if (!force) {
      final last = _lastRequestTime[roomName];
      if (last != null && now.difference(last) < const Duration(seconds: 3)) {
        return;
      }
    }
    _lastRequestTime[roomName] = now;

    Log.d(
      'HandshakeHandler',
      'Requesting HANDSHAKE from peers in $roomName...',
    );

    final packet = P2PPacket()
      ..type = P2PPacket_PacketType.HANDSHAKE
      ..requestId = const Uuid().v4()
      ..senderId = getLocalParticipantIdForRoom(roomName)
      ..payload = [];

    await broadcast(roomName, packet);
  }

  /// Handles an incoming HANDSHAKE packet.
  ///
  /// Returns the TreeKEM public key if present (for advanced key rotation).
  Future<List<int>?> handleHandshake(
    String roomName,
    P2PPacket packet,
    VoidCallback onNewPeer,
  ) async {
    // Empty payload = request for our handshake
    if (packet.payload.isEmpty) {
      Log.d(
        'HandshakeHandler',
        'Received HANDSHAKE REQUEST from ${packet.senderId}. Replying...',
      );
      await broadcastHandshake(roomName, force: true);
      return null;
    }

    // Store the signing public key
    Log.d('HandshakeHandler', 'Received HANDSHAKE KEY from ${packet.senderId}');
    _knownPublicKeysByRoom.putIfAbsent(roomName, () => {})[packet.senderId] =
        packet.payload;

    // Store encryption key if present
    if (packet.hasEncryptionPublicKey()) {
      _knownEncryptionKeysByRoom.putIfAbsent(
        roomName,
        () => {},
      )[packet.senderId] = packet.encryptionPublicKey;
      Log.d('HandshakeHandler', 'Stored Encryption Key for ${packet.senderId}');
      onNewPeer();
    }

    Log.d('HandshakeHandler', 'Stored Public Key for ${packet.senderId}');

    // Return onboarding key: encryption key (X25519) is prioritized for TreeKEM
    if (packet.hasEncryptionPublicKey() &&
        packet.encryptionPublicKey.isNotEmpty) {
      return packet.encryptionPublicKey;
    }
    if (packet.hasSenderPublicKey() && packet.senderPublicKey.isNotEmpty) {
      return packet.senderPublicKey;
    }
    return null;
  }

  /// Gets the public key for a sender, or null if unknown.
  List<int>? getPublicKey(String roomName, String senderId) =>
      _knownPublicKeysByRoom[roomName]?[senderId];

  /// Gets the encryption key for a sender, or null if unknown.
  List<int>? getEncryptionKey(String roomName, String senderId) =>
      _knownEncryptionKeysByRoom[roomName]?[senderId];

  /// Buffers a packet for later processing when we receive the sender's key.
  void bufferPacket(String roomName, String senderId, P2PPacket packet) {
    Log.d(
      'HandshakeHandler',
      'Buffering packet from unknown sender $senderId (room: $roomName)',
    );
    _pendingPacketsByRoom
        .putIfAbsent(roomName, () => {})
        .putIfAbsent(senderId, () => [])
        .add(packet);
  }

  /// Gets and clears pending packets for a sender.
  List<P2PPacket> clearPendingPackets(String roomName, String senderId) {
    final pending = _pendingPacketsByRoom[roomName]?[senderId] ?? [];
    _pendingPacketsByRoom[roomName]?.remove(senderId);
    return pending;
  }

  /// Waits for encryption keys from all remote participants.
  Future<void> waitForRemoteKeys(
    String roomName,
    Iterable<String> remoteIdentities, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (remoteIdentities.isEmpty) return;

    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      bool missingKeys = false;
      for (final identity in remoteIdentities) {
        if (_knownEncryptionKeysByRoom[roomName]?[identity] == null) {
          missingKeys = true;
          break;
        }
      }

      if (!missingKeys) {
        Log.d('HandshakeHandler', 'All remote keys available. Proceeding.');
        return;
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    Log.w(
      'HandshakeHandler',
      'WARNING: Timed out waiting for keys. Proceeding anyway.',
    );
  }

  /// Clears throttle timestamps for a room so handshakes happen immediately on reconnect.
  void clearRoom(String roomName) {
    _lastBroadcastTime.remove(roomName);
    _lastRequestTime.remove(roomName);
    _knownPublicKeysByRoom.remove(roomName);
    _knownEncryptionKeysByRoom.remove(roomName);
    _pendingPacketsByRoom.remove(roomName);
  }

  /// Clears all stored keys (for disconnect/cleanup).
  void clear() {
    _knownPublicKeysByRoom.clear();
    _knownEncryptionKeysByRoom.clear();
    _pendingPacketsByRoom.clear();
    _lastBroadcastTime.clear();
    _lastRequestTime.clear();
  }
}
