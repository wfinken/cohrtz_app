import 'dart:async';
import 'dart:convert';
import 'package:cohortz/src/generated/p2p_packet.pb.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:cryptography/cryptography.dart';

import '../../../shared/utils/logging_service.dart';
import '../../../shared/utils/sync_diagnostics.dart';

import '../../../shared/security/security_service.dart';
import '../../../shared/security/encryption_service.dart';

import 'connection_manager.dart';
import 'hybrid_time_service.dart';

class DataBroadcaster {
  final SecurityService _securityService;
  final EncryptionService _encryptionService;
  final HybridTimeService _hybridTimeService;
  final ConnectionManager Function()
  _getConnectionManager; // To access Rooms lazily
  final Future<SecretKey> Function(String roomName, {bool allowWait})
  _getGroupKey;
  final List<int>? Function(String roomName, String identity) _getEncryptionKey;
  final String Function(String roomName) _getLocalParticipantIdForRoom;

  DataBroadcaster({
    required SecurityService securityService,
    required EncryptionService encryptionService,
    required HybridTimeService hybridTimeService,
    required ConnectionManager Function() getConnectionManager,
    required Future<SecretKey> Function(String roomName, {bool allowWait})
    getGroupKey,
    required List<int>? Function(String roomName, String identity)
    getEncryptionKey,
    required String Function(String roomName) getLocalParticipantIdForRoom,
  }) : _securityService = securityService,
       _encryptionService = encryptionService,
       _hybridTimeService = hybridTimeService,
       _getConnectionManager = getConnectionManager,
       _getGroupKey = getGroupKey,
       _getEncryptionKey = getEncryptionKey,
       _getLocalParticipantIdForRoom = getLocalParticipantIdForRoom;

  Future<void> broadcast(String roomName, P2PPacket packet) async {
    final room = _getConnectionManager().getRoom(roomName);
    if (room == null || room.connectionState != ConnectionState.connected) {
      return;
    }

    // Stamp envelope timestamps once (buffered packets keep their original values).
    _hybridTimeService.stampOutgoingPacket(packet);

    // 1. Plaintext Broadcast (Handshakes / Invites / Key Requests)
    // UNICAST_REQ is used for GSK_REQ (requesting the group key) which must be done before we have the key.
    if (packet.type == P2PPacket_PacketType.HANDSHAKE ||
        packet.type == P2PPacket_PacketType.INVITE_REQ ||
        packet.type == P2PPacket_PacketType.INVITE_ACK ||
        packet.type == P2PPacket_PacketType.INVITE_NACK ||
        packet.type == P2PPacket_PacketType.UNICAST_REQ) {
      _emitPacketDiagnostic(
        roomName: roomName,
        packet: packet,
        direction: SyncDiagnosticDirection.outbound,
        message:
            'Broadcast ${_packetLabel(packet.type)} control packet to room peers.',
      );
      await _securityService.signPacket(packet, groupId: roomName);
      try {
        await _publishWithRetry(room, packet.writeToBuffer());
      } catch (e) {
        Log.w(
          'DataBroadcaster',
          'Failed to broadcast plaintext packet in $roomName after retries: $e. Buffering...',
        );
        _bufferPacket(roomName, packet);
      }
      return;
    }

    if (packet.encrypted) {
      // already encrypted (e.g. retry), just send
      _emitPacketDiagnostic(
        roomName: roomName,
        packet: packet,
        direction: SyncDiagnosticDirection.outbound,
        message: 'Broadcast encrypted ${_packetLabel(packet.type)} packet.',
      );
      await _publishWithRetry(room, packet.writeToBuffer());
      return;
    }

    if (packet.type == P2PPacket_PacketType.SYNC_REQ ||
        packet.type == P2PPacket_PacketType.SYNC_CLAIM) {
      final remoteParticipants = room.remoteParticipants.values.toList(
        growable: false,
      );
      var sentToAnyKey = false;

      if (remoteParticipants.isNotEmpty) {
        for (final participant in remoteParticipants) {
          final targetIdentity = participant.identity;
          if (targetIdentity.isEmpty) continue;
          if (_getEncryptionKey(roomName, targetIdentity) != null) {
            sentToAnyKey = true;
          }
          await sendSecurePacket(roomName, targetIdentity, packet);
        }

        if (sentToAnyKey) {
          return;
        }
      }

      try {
        final gsk = await _getGroupKey(roomName, allowWait: false);

        final gskPacket = P2PPacket.fromBuffer(packet.writeToBuffer());
        _hybridTimeService.stampOutgoingPacket(gskPacket);
        final payloadToEncrypt = gskPacket.payload.isNotEmpty
            ? gskPacket.payload
            : gskPacket.requestId.codeUnits;

        final encryptedPayload = await _encryptionService.encrypt(
          payloadToEncrypt,
          gsk,
        );

        gskPacket.encrypted = true;
        gskPacket.payload = encryptedPayload;
        await _securityService.signPacket(gskPacket, groupId: roomName);

        await _publishWithRetry(room, gskPacket.writeToBuffer());
        _emitPacketDiagnostic(
          roomName: roomName,
          packet: gskPacket,
          direction: SyncDiagnosticDirection.outbound,
          message:
              'Broadcast encrypted ${_packetLabel(gskPacket.type)} packet with group key.',
        );
        return;
      } catch (e) {
        Log.w(
          'DataBroadcaster',
          'Failed to broadcast SYNC packet with GSK in $roomName: $e. Buffering...',
        );
        _bufferPacket(roomName, packet);
        return;
      }
    }

    if (packet.type == P2PPacket_PacketType.DATA_CHUNK ||
        packet.type == P2PPacket_PacketType.CONSISTENCY_CHECK) {
      try {
        final gsk = await _getGroupKey(roomName, allowWait: false);

        // Diagnostic log: we can't easily tell if it's TreeKEM vs Legacy here
        // without looking at the bytes or having KeyManager return metadata.
        // For now, simple log.
        Log.d('DataBroadcaster', 'Encrypting broadcast with GSK for $roomName');

        final payloadToEncrypt = packet.payload.isNotEmpty
            ? packet.payload
            : packet.requestId.codeUnits;

        final encryptedPayload = await _encryptionService.encrypt(
          payloadToEncrypt,
          gsk,
        );

        packet.encrypted = true;
        packet.payload = encryptedPayload;
        await _securityService.signPacket(packet, groupId: roomName);

        await _publishWithRetry(room, packet.writeToBuffer());
        _emitPacketDiagnostic(
          roomName: roomName,
          packet: packet,
          direction: SyncDiagnosticDirection.outbound,
          message:
              'Broadcast encrypted ${_packetLabel(packet.type)} payload with group key.',
        );
        return;
      } catch (e) {
        Log.w(
          'DataBroadcaster',
          'Failed to broadcast E2EE packet in $roomName: $e. Attempting pairwise fallback...',
        );
        final remoteParticipants = room.remoteParticipants.values.toList(
          growable: false,
        );
        if (remoteParticipants.isNotEmpty) {
          for (final participant in remoteParticipants) {
            final targetIdentity = participant.identity;
            if (targetIdentity.isEmpty) continue;
            await sendSecurePacket(roomName, targetIdentity, packet);
          }
          return;
        }
        _bufferPacket(roomName, packet);
      }
    }

    // 3. Fallback / Specific Multi-Unicast
    // If we didn't return above, imply we want to send to everyone but via unicast?
    // Or if packet type is UNICAST_REQ (but broadcast called?) - Usually broadcast is for ... broadcast.
    // SyncService fell back to multi-unicast if GSK failed or logic fell through.
  }

  final Map<String, List<P2PPacket>> _outgoingQueue = {};
  final Map<String, Map<String, List<P2PPacket>>> _pendingUnicast = {};
  Timer? _flushTimer;

  void _bufferPacket(String roomName, P2PPacket packet) {
    _outgoingQueue.putIfAbsent(roomName, () => []);
    final queue = _outgoingQueue[roomName]!;
    if (_shouldDeDuplicateControlPacket(packet) &&
        queue.any(
          (queued) =>
              queued.type == packet.type && queued.senderId == packet.senderId,
        )) {
      return;
    }

    queue.add(packet);
    Log.d(
      'DataBroadcaster',
      'Buffered outgoing packet (Type: ${packet.type}) for $roomName. Queue size: ${queue.length}',
    );
    _startFlushTimer();
  }

  void _startFlushTimer() {
    if (_flushTimer != null && _flushTimer!.isActive) return;
    Log.d('DataBroadcaster', 'Starting buffer flush timer...');
    _flushTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_outgoingQueue.isEmpty) {
        timer.cancel();
        _flushTimer = null;
        Log.d('DataBroadcaster', 'Buffer empty. Stopping flush timer.');
        return;
      }

      // Retry all rooms
      for (final roomName in _outgoingQueue.keys.toList()) {
        retryBufferedPackets(roomName);
      }
    });
  }

  Future<void> retryBufferedPackets(String roomName) async {
    final queue = _outgoingQueue[roomName];
    if (queue == null || queue.isEmpty) {
      // Cleanup empty key
      _outgoingQueue.remove(roomName);
      return;
    }

    Log.i(
      'DataBroadcaster',
      'Retrying ${queue.length} buffered packets for $roomName...',
    );

    // Copy and clear queue to prevent loops, but if they fail again they'll be re-buffered
    final toRetry = List<P2PPacket>.from(queue);
    queue.clear();

    for (final packet in toRetry) {
      // Recursively call broadcast or publish
      if (packet.encrypted) {
        // Already encrypted, just try to publish
        try {
          final room = _getConnectionManager().getRoom(roomName);
          if (room != null) {
            await _publishWithRetry(room, packet.writeToBuffer());
            Log.d(
              'DataBroadcaster',
              'Successfully resent buffered (encrypted) packet for $roomName',
            );
          }
        } catch (e) {
          // If it fails again, re-buffer?
          _bufferPacket(roomName, packet);
        }
      } else {
        // Not encrypted, retry full flow
        try {
          await broadcast(roomName, packet);
          Log.d(
            'DataBroadcaster',
            'Successfully processed buffered (raw) packet for $roomName',
          );
        } catch (e) {
          // broadcast internally buffers if it fails due to key/timeout
          // but if it fails immediately, we might need to handle it?
          // broadcast catches its own errors and buffers.
          // no op here.
          Log.w('DataBroadcaster', 'Retry failed for raw packet: $e');
        }
      }
    }

    // Check if we can stop timer (if all empty)
    if (_outgoingQueue.values.every((l) => l.isEmpty)) {
      _outgoingQueue.clear();
    }
  }

  Future<void> sendSecurePacket(
    String roomName,
    String targetIdentity,
    P2PPacket packet,
  ) async {
    final room = _getConnectionManager().getRoom(roomName);
    if (room == null) return;

    // Stamp envelope timestamps once (buffered packets keep their original values).
    _hybridTimeService.stampOutgoingPacket(packet);

    final remoteEncKey = _getEncryptionKey(roomName, targetIdentity);
    if (remoteEncKey == null) {
      Log.w(
        'DataBroadcaster',
        'WARNING: No encryption key for $targetIdentity',
      );
      _bufferUnicast(roomName, targetIdentity, packet);
      return;
    }

    try {
      final sessionKey = await _securityService.deriveSharedSecret(
        remoteEncKey,
        salt: utf8.encode(roomName),
        groupId: roomName,
      );

      final payloadToEncrypt = packet.payload.isNotEmpty
          ? packet.payload
          : packet.requestId.codeUnits;

      final encryptedPayload = await _encryptionService.encrypt(
        payloadToEncrypt,
        sessionKey,
      );

      final unicastPacket = P2PPacket()
        ..type = packet.type
        ..requestId = packet.requestId
        ..senderId = _getLocalParticipantIdForRoom(roomName)
        ..physicalTime = packet.physicalTime
        ..logicalTime = packet.logicalTime
        ..encrypted = true
        ..payload = encryptedPayload;

      _emitPacketDiagnostic(
        roomName: roomName,
        packet: unicastPacket,
        direction: SyncDiagnosticDirection.outbound,
        peerId: targetIdentity,
        message:
            'Sent secure ${_packetLabel(unicastPacket.type)} packet to $targetIdentity.',
      );

      await _securityService.signPacket(unicastPacket, groupId: roomName);

      await _publishWithRetry(
        room,
        unicastPacket.writeToBuffer(),
        destinationIdentities: [targetIdentity],
      );
    } catch (e) {
      Log.e(
        'DataBroadcaster',
        'Failed to send E2EE packet to $targetIdentity after retries',
        e,
      );
    }
  }

  void _bufferUnicast(
    String roomName,
    String targetIdentity,
    P2PPacket packet,
  ) {
    _pendingUnicast.putIfAbsent(roomName, () => {});
    _pendingUnicast[roomName]!.putIfAbsent(targetIdentity, () => []);
    final queue = _pendingUnicast[roomName]![targetIdentity]!;
    if (_shouldDeDuplicateControlPacket(packet) &&
        queue.any(
          (queued) =>
              queued.type == packet.type && queued.senderId == packet.senderId,
        )) {
      return;
    }
    queue.add(packet);
    Log.d(
      'DataBroadcaster',
      'Buffered secure packet for $targetIdentity in $roomName. Queue size: ${queue.length}',
    );
  }

  bool _shouldDeDuplicateControlPacket(P2PPacket packet) {
    return packet.type == P2PPacket_PacketType.HANDSHAKE ||
        packet.type == P2PPacket_PacketType.SYNC_REQ ||
        packet.type == P2PPacket_PacketType.SYNC_CLAIM;
  }

  Future<void> retryPendingUnicast(
    String roomName, [
    String? targetIdentity,
  ]) async {
    final byTarget = _pendingUnicast[roomName];
    if (byTarget == null || byTarget.isEmpty) return;

    final targets = targetIdentity != null
        ? [targetIdentity]
        : byTarget.keys.toList();

    for (final target in targets) {
      final queue = byTarget[target];
      if (queue == null || queue.isEmpty) continue;

      // Only retry if we now have an encryption key
      if (_getEncryptionKey(roomName, target) == null) continue;

      final toRetry = List<P2PPacket>.from(queue);
      queue.clear();

      for (final packet in toRetry) {
        await sendSecurePacket(roomName, target, packet);
      }

      if (queue.isEmpty) {
        byTarget.remove(target);
      }
    }

    if (byTarget.isEmpty) {
      _pendingUnicast.remove(roomName);
    }
  }

  Future<void> _publishWithRetry(
    Room room,
    List<int> data, {
    List<String>? destinationIdentities,
  }) async {
    int attempts = 0;
    const maxAttempts = 10; // Increased to 10 for robust connection handling
    while (attempts < maxAttempts) {
      try {
        if (room.connectionState != ConnectionState.connected) {
          throw StateError('Room is not connected: ${room.connectionState}');
        }

        final participant = room.localParticipant;
        if (participant == null) {
          // This can happen if we are "connected" but the local participant object hasn't propagated yet
          throw StateError('Local participant is null');
        }

        await participant.publishData(
          data,
          reliable: true,
          destinationIdentities: destinationIdentities,
        );
        return; // Success
      } catch (e) {
        attempts++;
        final errorStr = e.toString();
        // Specifically look for data channel readiness issues OR null participant race
        if ((errorStr.contains('dataChannel not found') ||
                errorStr.contains('not opened') ||
                errorStr.contains('Local participant is null')) &&
            attempts < maxAttempts) {
          final delayMs = 200 * attempts; // 200, 400, 600, 800ms...
          Log.w(
            'DataBroadcaster',
            'Data channel not ready (or participant null), retrying in ${delayMs}ms (attempt $attempts/$maxAttempts)...',
          );
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          // If it's a different error or we're out of attempts, stop retrying.
          rethrow;
        }
      }
    }
  }

  void _emitPacketDiagnostic({
    required String roomName,
    required P2PPacket packet,
    required SyncDiagnosticDirection direction,
    required String message,
    String? peerId,
  }) {
    SyncDiagnostics.emit(
      tag: 'DataBroadcaster',
      message: message,
      roomName: roomName,
      peerId: peerId,
      kind: _kindForPacket(packet.type),
      direction: direction,
      bytes: packet.payload.length,
    );
  }

  String _packetLabel(P2PPacket_PacketType type) {
    switch (type) {
      case P2PPacket_PacketType.HANDSHAKE:
        return 'HANDSHAKE';
      case P2PPacket_PacketType.SYNC_REQ:
        return 'SYNC_REQ';
      case P2PPacket_PacketType.SYNC_CLAIM:
        return 'SYNC_CLAIM';
      case P2PPacket_PacketType.DATA_CHUNK:
        return 'DATA_CHUNK';
      case P2PPacket_PacketType.CONSISTENCY_CHECK:
        return 'CONSISTENCY_CHECK';
      case P2PPacket_PacketType.INVITE_REQ:
        return 'INVITE_REQ';
      case P2PPacket_PacketType.INVITE_ACK:
        return 'INVITE_ACK';
      case P2PPacket_PacketType.INVITE_NACK:
        return 'INVITE_NACK';
      case P2PPacket_PacketType.UNICAST_REQ:
        return 'UNICAST_REQ';
      case P2PPacket_PacketType.UNICAST_ACK:
        return 'UNICAST_ACK';
    }
    return 'UNKNOWN';
  }

  SyncDiagnosticKind _kindForPacket(P2PPacket_PacketType type) {
    switch (type) {
      case P2PPacket_PacketType.HANDSHAKE:
        return SyncDiagnosticKind.handshake;
      case P2PPacket_PacketType.SYNC_REQ:
      case P2PPacket_PacketType.SYNC_CLAIM:
      case P2PPacket_PacketType.CONSISTENCY_CHECK:
        return SyncDiagnosticKind.sync;
      case P2PPacket_PacketType.DATA_CHUNK:
        return SyncDiagnosticKind.data;
      default:
        return SyncDiagnosticKind.info;
    }
  }
}
