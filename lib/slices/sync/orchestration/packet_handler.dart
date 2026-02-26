import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cohortz/src/generated/p2p_packet.pb.dart';

import '../../../shared/utils/logging_service.dart';
import '../../../shared/utils/sync_diagnostics.dart';
import '../../../shared/security/security_service.dart';
import '../../../shared/security/encryption_service.dart';
import '../../vault/state/packet_store.dart';
import '../../vault/models/stored_packet.dart';
import '../runtime/crdt_service.dart';
import '../runtime/group_manager.dart';
import '../runtime/hlc_compat.dart';
import '../runtime/hybrid_time_service.dart';
import 'handshake_handler.dart';
import 'invite_handler.dart';
import 'sync_protocol.dart';
import '../runtime/key_manager.dart';
import '../runtime/treekem_handler.dart';

typedef PacketControlHandler =
    Future<bool> Function(String roomName, P2PPacket packet);

class PacketHandler {
  final HybridTimeService _hybridTimeService;
  final SecurityService _securityService;
  final EncryptionService _encryptionService;
  final PacketStore _packetStore;
  final CrdtService _crdtService;
  final GroupManager _groupManager;

  // Delegated Handlers
  final HandshakeHandler _handshakeHandler;
  final InviteHandler _inviteHandler;
  final SyncProtocol _syncProtocol;
  final TreeKemHandler _treekemHandler;
  final KeyManager _keyManager;

  final String Function(String roomName) _getLocalParticipantIdForRoom;
  final Function(String roomName) _broadcastConsistencyCheck;
  final Function(String roomName, String targetId, P2PPacket packet)
  _sendSecurePacket;
  final Future<void> Function(String roomName, P2PPacket packet) _broadcast;
  final Function(String roomName) retryBroadcast;
  final Function(String roomName, String targetId) onGroupKeyShared;
  final Function(String roomName, SecretKey key) onGroupKeyUpdated;
  final Function(String roomName, String peerId) onPeerHandshake;
  final Future<String?> Function(String roomName)
  _getLocalUserProfileJsonForRoom;

  // State
  // Map of RoomId -> Session Key (for unicast rooms)
  final Map<String, SecretKey> _sessionKeys = {};

  // Buffer for GSK-encrypted packets
  final Map<String, List<(P2PPacket, List<int>)>> _packetsAwaitingGsk = {};
  final Map<String, DateTime> _lastProfileBroadcast = {};
  late final Map<P2PPacket_PacketType, PacketControlHandler>
  _packetControlHandlers;

  PacketHandler({
    required HybridTimeService hybridTimeService,
    required SecurityService securityService,
    required EncryptionService encryptionService,
    required PacketStore packetStore,
    required CrdtService crdtService,
    required GroupManager groupManager,
    required HandshakeHandler handshakeHandler,
    required InviteHandler inviteHandler,
    required SyncProtocol syncProtocol,
    required TreeKemHandler treekemHandler,
    required KeyManager keyManager,
    required String Function(String roomName) getLocalParticipantIdForRoom,
    required Function(String roomName) broadcastConsistencyCheck,
    required Function(String roomName, String targetId, P2PPacket packet)
    sendSecurePacket,
    required Future<void> Function(String roomName, P2PPacket packet) broadcast,
    required this.retryBroadcast,
    required this.onGroupKeyShared,
    required this.onGroupKeyUpdated,
    required this.onPeerHandshake,
    required Future<String?> Function(String roomName)
    getLocalUserProfileJsonForRoom,
  }) : _hybridTimeService = hybridTimeService,
       _securityService = securityService,
       _encryptionService = encryptionService,
       _packetStore = packetStore,
       _crdtService = crdtService,
       _groupManager = groupManager,
       _handshakeHandler = handshakeHandler,
       _inviteHandler = inviteHandler,
       _syncProtocol = syncProtocol,
       _treekemHandler = treekemHandler,
       _keyManager = keyManager,
       _getLocalParticipantIdForRoom = getLocalParticipantIdForRoom,
       _broadcastConsistencyCheck = broadcastConsistencyCheck,
       _sendSecurePacket = sendSecurePacket,
       _broadcast = broadcast,
       _getLocalUserProfileJsonForRoom = getLocalUserProfileJsonForRoom {
    _packetControlHandlers = {
      P2PPacket_PacketType.UNICAST_REQ: _handleUnicastControlPacket,
      P2PPacket_PacketType.HANDSHAKE: _handleHandshakePacket,
      P2PPacket_PacketType.INVITE_REQ: _handleInviteReqPacket,
      P2PPacket_PacketType.INVITE_ACK: _handleInviteAckPacket,
      P2PPacket_PacketType.INVITE_NACK: _handleInviteNackPacket,
    };
    _treekemHandler.keyUpdates.listen((event) {
      updateGroupKey(event.$1, event.$2);
    });
  }

  void _fireAndForget(String operation, FutureOr<void> Function() action) {
    unawaited(
      Future.sync(action).catchError((Object error, StackTrace stackTrace) {
        Log.e(
          'PacketHandler',
          'Async operation failed: $operation',
          error,
          stackTrace,
        );
      }),
    );
  }

  // Update Group Key (called when TreekemHandler or peers update it)
  void updateGroupKey(String roomName, SecretKey key) {
    _keyManager.setGroupKey(roomName, key);
    onGroupKeyUpdated(roomName, key);
    _replayBufferedPackets(roomName);
    _fireAndForget(
      'retryBroadcast for $roomName after group key update',
      () => retryBroadcast(roomName),
    );
  }

  Future<void> onDataReceived(String roomName, List<int> data) async {
    try {
      final packet = P2PPacket.fromBuffer(data);
      SyncDiagnostics.emit(
        tag: 'PacketHandler',
        message:
            'Received ${_packetLabel(packet.type)} packet from ${packet.senderId}.',
        roomName: roomName,
        peerId: packet.senderId,
        kind: _kindForPacket(packet.type),
        direction: SyncDiagnosticDirection.inbound,
        bytes: data.length,
      );

      final localId = _getLocalParticipantIdForRoom(roomName);
      if (packet.targetId.isNotEmpty && packet.targetId != localId) {
        return;
      }

      final controlHandler = _packetControlHandlers[packet.type];
      if (controlHandler != null) {
        final handled = await controlHandler(roomName, packet);
        if (handled) return;
      }

      final pubKey = _handshakeHandler.getPublicKey(roomName, packet.senderId);
      if (pubKey == null) {
        Log.w(
          'PacketHandler',
          'WARNING: Unknown sender ${packet.senderId} in $roomName. Buffering & Requesting Handshake.',
        );
        _handshakeHandler.bufferPacket(roomName, packet.senderId, packet);
        _handshakeHandler.requestHandshake(roomName);
        return;
      }

      await _processVerifiedPacket(roomName, packet, pubKey);
    } catch (e) {
      Log.e('PacketHandler', 'Error parsing packet', e);
    }
  }

  Future<bool> _handleUnicastControlPacket(
    String roomName,
    P2PPacket packet,
  ) async {
    return _maybeHandleTimeSyncControl(roomName, packet);
  }

  Future<bool> _handleHandshakePacket(String roomName, P2PPacket packet) async {
    _hybridTimeService.observeIncomingPacket(packet);
    final newTreeKemKey = await _handshakeHandler.handleHandshake(
      roomName,
      packet,
      () {
        _fireAndForget(
          'broadcast local profile for $roomName',
          () => _maybeBroadcastLocalProfile(roomName),
        );
        _fireAndForget(
          'onPeerHandshake for $roomName',
          () => onPeerHandshake(roomName, packet.senderId),
        );
        final group = _groupManager.findGroup(roomName);
        if (group.isEmpty || group['isInviteRoom'] != 'true') {
          _fireAndForget(
            'requestSync for $roomName after handshake',
            () => _syncProtocol.requestSync(roomName),
          );
          _fireAndForget(
            'onGroupKeyShared for $roomName',
            () => onGroupKeyShared(roomName, packet.senderId),
          );
        }
      },
    );

    if (newTreeKemKey != null) {
      final group = _groupManager.findGroup(roomName);
      if (group.isNotEmpty && group['isInviteRoom'] == 'true') {
        Log.d(
          'PacketHandler',
          'Skipping TreeKEM onboarding for Invite Room: $roomName',
        );
      } else {
        Log.i(
          'PacketHandler',
          'Handshake contained TreeKEM key from ${packet.senderId}. Initiating onboarding.',
        );
        await _attemptOnboard(roomName, packet.senderId, newTreeKemKey);
      }
    }

    final senderPubKey = _handshakeHandler.getPublicKey(
      roomName,
      packet.senderId,
    );
    if (senderPubKey != null) {
      final pending = _handshakeHandler.clearPendingPackets(
        roomName,
        packet.senderId,
      );
      if (pending.isNotEmpty) {
        Log.i(
          'PacketHandler',
          'Replaying ${pending.length} buffered packets from ${packet.senderId} in $roomName after handshake.',
        );
        for (final bufferedPacket in pending) {
          await _processVerifiedPacket(roomName, bufferedPacket, senderPubKey);
        }
      }
    }
    return true;
  }

  Future<bool> _handleInviteReqPacket(String roomName, P2PPacket packet) async {
    _hybridTimeService.observeIncomingPacket(packet);
    _inviteHandler.handleInviteReq(roomName, packet);
    return true;
  }

  Future<bool> _handleInviteAckPacket(String roomName, P2PPacket packet) async {
    _hybridTimeService.observeIncomingPacket(packet);
    _inviteHandler.handleInviteAck(roomName, packet);
    return true;
  }

  Future<bool> _handleInviteNackPacket(
    String roomName,
    P2PPacket packet,
  ) async {
    _hybridTimeService.observeIncomingPacket(packet);
    _inviteHandler.handleInviteNack(roomName, packet);
    return true;
  }

  Future<void> _maybeBroadcastLocalProfile(String roomName) async {
    final group = _groupManager.findGroup(roomName);
    if (group.isNotEmpty && group['isInviteRoom'] == 'true') return;

    final now = DateTime.now();
    final last = _lastProfileBroadcast[roomName];
    if (last != null && now.difference(last) < const Duration(seconds: 10)) {
      return;
    }

    final profileJson = await _getLocalUserProfileJsonForRoom(roomName);
    if (profileJson == null || profileJson.isEmpty) return;

    final localId = _getLocalParticipantIdForRoom(roomName);
    if (localId.isEmpty) return;

    _lastProfileBroadcast[roomName] = now;
    await _crdtService.put(
      roomName,
      localId,
      profileJson,
      tableName: 'user_profiles',
    );
  }

  /// Attempts to onboard a new member to the TreeKEM group if we are already a member/host.
  Future<void> _attemptOnboard(
    String roomName,
    String senderId,
    List<int> treeKemKey,
  ) async {
    final service = _treekemHandler.getService(roomName);
    if (service == null) {
      return;
    }

    // Check if member already exists to avoid re-adding
    if (_treekemHandler.memberExists(roomName, treeKemKey)) {
      return;
    }

    try {
      Log.i(
        'PacketHandler',
        'Onboarding $senderId to TreeKEM group with key length: ${treeKemKey.length}...',
      );
      final result = await _treekemHandler.addMember(roomName, treeKemKey);

      // 1. Send WELCOME (Unicast to new member)
      final welcomePacket = P2PPacket()
        ..type = P2PPacket_PacketType.UNICAST_REQ
        ..requestId = const Uuid().v4()
        ..senderId = _getLocalParticipantIdForRoom(roomName)
        ..payload = utf8.encode(
          jsonEncode({
            'type': 'Treekem_WELCOME',
            'epoch': result.epoch,
            ...result.welcome.toJson(), // flatten into map
          }),
        );
      // Wait, UNICAST_REQ payload is usually a JSON string for these custom types
      // Checking _handleUnicastReq logic...
      // it expects `jsonDecode(jsonStr) as Map`.
      // So payload should be utf8 bytes of JSON string.

      await _sendSecurePacket(roomName, senderId, welcomePacket);
      Log.d(
        'PacketHandler',
        'Sent TreeKEM WELCOME to $senderId for leaf ${result.welcome.leafIndex}',
      );

      // 2. Send UPDATE (Multicast to existing group)
      final updatePathJson = result.updatePath.map((n) {
        return {
          'publicKey': base64Encode(n.publicKey),
          'encryptedPathSecrets': n.encryptedPathSecrets.map(
            (k, v) => MapEntry(k.toString(), base64Encode(v)),
          ),
        };
      }).toList();

      final updatePacket = P2PPacket()
        ..type = P2PPacket_PacketType
            .UNICAST_REQ // We overload UNICAST_REQ for "Control Messages" or should we use a new type?
        // Wait, _handleUnicastReq handles Treekem_UPDATE.
        // But broadcast sends to everyone.
        // If we use UNICAST_REQ type for broadcast, receivers will treat it as UNICAST_REQ.
        // PacketHandler._handleUnicastReq handles 'Treekem_UPDATE'.
        // So yes, we can use UNICAST_REQ type even if broadcast,
        // IF the receivers logic (_handleUnicastReq) supports the payload.
        ..requestId = const Uuid().v4()
        ..senderId = _getLocalParticipantIdForRoom(roomName)
        ..payload = utf8.encode(
          jsonEncode({
            'type': 'Treekem_UPDATE',
            'epoch': result.epoch,
            'senderLeafIndex': result.myLeafIndex,
            'updatePath': updatePathJson,
          }),
        );

      await _broadcast(roomName, updatePacket);
      Log.i('PacketHandler', 'Broadcasted TreeKEM UPDATE for new member.');
    } catch (e) {
      Log.e('PacketHandler', 'Failed to onboard member', e);
    }
  }

  /// Rotates local TreeKEM secrets and broadcasts the resulting epoch update.
  Future<int> rotateTreeKemEpoch(String roomName) async {
    final result = await _treekemHandler.rotateEpoch(roomName);

    final updatePathJson = result.updatePath
        .map(
          (n) => {
            'publicKey': base64Encode(n.publicKey),
            'encryptedPathSecrets': n.encryptedPathSecrets.map(
              (k, v) => MapEntry(k.toString(), base64Encode(v)),
            ),
          },
        )
        .toList();

    final updatePacket = P2PPacket()
      ..type = P2PPacket_PacketType.UNICAST_REQ
      ..requestId = const Uuid().v4()
      ..senderId = _getLocalParticipantIdForRoom(roomName)
      ..payload = utf8.encode(
        jsonEncode({
          'type': 'Treekem_UPDATE',
          'epoch': result.epoch,
          'senderLeafIndex': result.senderLeafIndex,
          'updatePath': updatePathJson,
        }),
      );

    await _broadcast(roomName, updatePacket);
    return result.epoch;
  }

  Future<void> _processVerifiedPacket(
    String roomName,
    P2PPacket packet,
    List<int> pubKey,
  ) async {
    if (packet.signature.isEmpty) {
      Log.w('PacketHandler', 'WARNING: Unsigned packet received. Ignoring.');
      return;
    }

    final isValid = await _securityService.verifyPacket(
      packet,
      publicKeyOverride: pubKey,
    );

    if (!isValid) {
      Log.e(
        'PacketHandler',
        'CRITICAL: Signature verification failed for ${packet.senderId}!',
      );
      return;
    }

    _hybridTimeService.observeIncomingPacket(packet);

    // DECRYPTION LADDER
    if (packet.encrypted) {
      if (!await _decryptPacket(roomName, packet, pubKey)) return;
    }

    // Save Data Chunks (Legacy/Audit)
    if (packet.type == P2PPacket_PacketType.DATA_CHUNK) {
      await _savePacket(roomName, packet);
    }

    await _dispatchVerifiedPacket(roomName, packet);
  }

  Future<bool> _decryptPacket(
    String roomName,
    P2PPacket packet,
    List<int> pubKey,
  ) async {
    try {
      SecretKey? sessionKey;
      bool decrypted = false;

      // CASE 1: Ephemeral Room (Unicast Tunnel) - assuming _sessionKeys populated
      if (_sessionKeys.containsKey(roomName)) {
        sessionKey = _sessionKeys[roomName];
        if (sessionKey != null) {
          try {
            packet.payload = await _encryptionService.decrypt(
              packet.payload,
              sessionKey,
            );
            decrypted = true;
          } catch (e) {
            // Unicast decryption failed
          }
        }
      } else {
        // CASE 2: Main Room (GSK or Pairwise)
        final isGskPacketType =
            packet.type == P2PPacket_PacketType.DATA_CHUNK ||
            packet.type == P2PPacket_PacketType.SYNC_REQ ||
            packet.type == P2PPacket_PacketType.SYNC_CLAIM ||
            packet.type == P2PPacket_PacketType.CONSISTENCY_CHECK;

        // A: Try GSK via KeyManager (Non-blocking)
        try {
          // Use allowWait: false to prevent blocking the packet loop
          final gsk = await _keyManager.getGroupKey(roomName, allowWait: false);
          packet.payload = await _encryptionService.decrypt(
            packet.payload,
            gsk,
            silent: true, // Don't log MAC errors here, we handle them below
          );
          decrypted = true;
          sessionKey = gsk;
        } catch (e) {
          // Key missing (StateError) or decryption failed
          // If StateError, we continue to buffering.
        }

        // B: Try Pairwise (fallback) if GSK failed or is unavailable.
        if (!decrypted) {
          final senderEncKey = _handshakeHandler.getEncryptionKey(
            roomName,
            packet.senderId,
          );
          if (senderEncKey != null) {
            sessionKey = await _securityService.deriveSharedSecret(
              senderEncKey,
              salt: utf8.encode(roomName),
              groupId: roomName,
            );
            try {
              packet.payload = await _encryptionService.decrypt(
                packet.payload,
                sessionKey,
                silent: true,
              );
              decrypted = true;
            } catch (_) {
              // Failed Pairwise
            }
          }
        }

        // C: Buffer if GSK needed
        // Buffering if isGskPacketType and decryption failed (either due to missing key or MAC error)
        if (!decrypted && isGskPacketType) {
          Log.d(
            'PacketHandler',
            'Buffering packet type ${packet.type} awaiting valid GSK for $roomName',
          );
          _packetsAwaitingGsk.putIfAbsent(roomName, () => []);
          _packetsAwaitingGsk[roomName]!.add((packet, pubKey));

          // Proactively request sync (which triggers GSK sharing from
          // the peer) so buffered packets can eventually be replayed.
          final group = _groupManager.findGroup(roomName);
          if (group.isEmpty || group['isInviteRoom'] != 'true') {
            _fireAndForget(
              'requestSync for $roomName while awaiting GSK packet',
              () => _syncProtocol.requestSync(roomName),
            );
          }
          return false;
        }
      }

      if (!decrypted) {
        Log.e(
          'PacketHandler',
          'CRITICAL: Failed to decrypt packet Type: ${packet.type} from ${packet.senderId}',
        );
        return false;
      }
      return true;
    } catch (e) {
      if (e is SecretBoxAuthenticationError) {
        // This catch might be redundant if we catch inside the specific blocks,
        // but ensures we catch any bubbling crypto errors.
        final isGskPacketType =
            packet.type == P2PPacket_PacketType.DATA_CHUNK ||
            packet.type == P2PPacket_PacketType.SYNC_REQ ||
            packet.type == P2PPacket_PacketType.SYNC_CLAIM ||
            packet.type == P2PPacket_PacketType.CONSISTENCY_CHECK;

        if (isGskPacketType) {
          Log.w(
            'PacketHandler',
            'Buffering packet type ${packet.type} due to MAC error ($e) - awaiting correct GSK for $roomName. Triggering re-sync.',
          );
          _packetsAwaitingGsk.putIfAbsent(roomName, () => []);
          _packetsAwaitingGsk[roomName]!.add((packet, pubKey));

          // Trigger Handshake/Sync to fetch latest keys (might have missed Update/Welcome after sleep)
          _handshakeHandler.requestHandshake(roomName, force: true);
          final group = _groupManager.findGroup(roomName);
          if (group.isEmpty || group['isInviteRoom'] != 'true') {
            _fireAndForget(
              'requestSync for $roomName after decrypt MAC error',
              () => _syncProtocol.requestSync(roomName),
            );
          }
        }
        return false;
      }

      Log.w('PacketHandler', 'Decryption error: $e');
      return false;
    }
  }

  Future<void> _dispatchVerifiedPacket(
    String roomName,
    P2PPacket packet,
  ) async {
    switch (packet.type) {
      case P2PPacket_PacketType.SYNC_REQ:
        _syncProtocol.handleSyncReq(
          roomName,
          packet,
          () => _syncProtocol.winElection(
            roomName,
            packet.requestId,
            packet.senderId,
            _syncProtocol.parseVectorClock(packet),
          ),
        );
        break;
      case P2PPacket_PacketType.SYNC_CLAIM:
        _syncProtocol.handleSyncClaim(roomName, packet);
        break;
      case P2PPacket_PacketType.DATA_CHUNK:
        await _mergeDataChunk(roomName, packet);
        break;
      case P2PPacket_PacketType.UNICAST_REQ:
        await _handleUnicastReq(roomName, packet);
        break;
      case P2PPacket_PacketType.CONSISTENCY_CHECK:
        // Handled by logging currently
        break;
      default:
        break;
    }
  }

  Future<void> _mergeDataChunk(String roomName, P2PPacket packet) async {
    try {
      final jsonString = utf8.decode(packet.payload);
      final Map<String, dynamic> decoded = jsonDecode(jsonString);

      final changeset = decoded.map((key, value) {
        final records = (value as List).cast<Map<String, dynamic>>();
        final parsedRecords = records.map((r) {
          final newRecord = Map<String, dynamic>.from(r);
          if (newRecord.containsKey('hlc') && newRecord['hlc'] is String) {
            final parsed = tryParseHlcCompat(newRecord['hlc'] as String);
            if (parsed != null) {
              newRecord['hlc'] = parsed;
            }
          }
          return newRecord;
        }).toList();
        return MapEntry(key, parsedRecords);
      });

      await _crdtService.merge(roomName, changeset);
      Log.d(
        'PacketHandler',
        'Merged data chunk from ${packet.senderId} in $roomName',
      );
      _fireAndForget(
        'broadcastConsistencyCheck for $roomName',
        () => _broadcastConsistencyCheck(roomName),
      );
    } catch (e) {
      Log.e('PacketHandler', 'Merge error', e);
    }
  }

  Future<bool> _maybeHandleTimeSyncControl(
    String roomName,
    P2PPacket packet,
  ) async {
    try {
      final jsonStr = utf8.decode(packet.payload);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final type = map['type'];

      if (type == 'SYNC_PING') {
        final t0Raw = map['t0'];
        final t0 = (t0Raw is num) ? t0Raw.toDouble() : double.nan;
        if (t0.isNaN) return true;

        final t1 = _hybridTimeService.perfNowMs();
        final t2 = _hybridTimeService.perfNowMs();
        final pong = _hybridTimeService.buildSyncPong(
          targetId: packet.senderId,
          requestId: packet.requestId,
          t0: t0,
          t1: t1,
          t2: t2,
          localParticipantId: _getLocalParticipantIdForRoom(roomName),
        );
        await _broadcast(roomName, pong);
        return true;
      }

      if (type == 'SYNC_PONG') {
        final t0Raw = map['t0'];
        final t1Raw = map['t1'];
        final t2Raw = map['t2'];
        final t0 = (t0Raw is num) ? t0Raw.toDouble() : double.nan;
        final t1 = (t1Raw is num) ? t1Raw.toDouble() : double.nan;
        final t2 = (t2Raw is num) ? t2Raw.toDouble() : double.nan;
        if (t0.isNaN || t1.isNaN || t2.isNaN) return true;

        _hybridTimeService.handleIncomingSyncPong(
          peerId: packet.senderId,
          t0: t0,
          t1: t1,
          t2: t2,
        );
        return true;
      }
    } catch (_) {
      // Not a JSON control message.
    }

    return false;
  }

  Future<void> _handleUnicastReq(String roomName, P2PPacket packet) async {
    try {
      final jsonStr = utf8.decode(packet.payload);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final type = map['type'];

      if (type == 'SYNC_PING') {
        final t0Raw = map['t0'];
        final t0 = (t0Raw is num) ? t0Raw.toDouble() : double.nan;
        if (t0.isNaN) return;

        final t1 = _hybridTimeService.perfNowMs();
        final t2 = _hybridTimeService.perfNowMs();
        final pong = _hybridTimeService.buildSyncPong(
          targetId: packet.senderId,
          requestId: packet.requestId,
          t0: t0,
          t1: t1,
          t2: t2,
          localParticipantId: _getLocalParticipantIdForRoom(roomName),
        );
        await _broadcast(roomName, pong);
      } else if (type == 'SYNC_PONG') {
        final t0Raw = map['t0'];
        final t1Raw = map['t1'];
        final t2Raw = map['t2'];
        final t0 = (t0Raw is num) ? t0Raw.toDouble() : double.nan;
        final t1 = (t1Raw is num) ? t1Raw.toDouble() : double.nan;
        final t2 = (t2Raw is num) ? t2Raw.toDouble() : double.nan;
        if (t0.isNaN || t1.isNaN || t2.isNaN) return;

        _hybridTimeService.handleIncomingSyncPong(
          peerId: packet.senderId,
          t0: t0,
          t1: t1,
          t2: t2,
        );
      } else if (type == 'GSK_REQ') {
        _fireAndForget(
          'onGroupKeyShared (GSK_REQ) for $roomName',
          () => onGroupKeyShared(roomName, packet.senderId),
        );
      } else if (type == 'KEY_REQ') {
        await _keyManager.shareVaultKeyIfHeld(roomName, packet.senderId);
      } else if (type == 'ROOM_KEY') {
        final keyStr = map['key'] as String;
        await _keyManager.handleVaultKeyShare(roomName, keyStr);
      } else if (type == 'Treekem_UPDATE') {
        await _treekemHandler.handleUpdate(roomName, packet.senderId, map);
      } else if (type == 'Treekem_WELCOME') {
        await _treekemHandler.handleWelcome(roomName, map);
      } else if (type == 'GSK_SHARE') {
        final keyStr = map['key'] as String;
        await _keyManager.handleGskShare(roomName, keyStr);
        final keyBytes = base64Decode(keyStr);
        final key = SecretKey(keyBytes);
        updateGroupKey(roomName, key); // Replays incoming buffers
        _fireAndForget(
          'retryBroadcast for $roomName after GSK_SHARE',
          () => retryBroadcast(roomName),
        ); // Retries outgoing buffers
      }
    } catch (e) {
      Log.e('PacketHandler', 'Unicast handling error', e);
    }
  }

  Future<void> _savePacket(String roomName, P2PPacket packet) async {
    final stored = StoredPacket(
      requestId: packet.requestId,
      senderId: packet.senderId,
      timestamp: DateTime.now(),
      packetType: packet.type.value,
      payload: packet.payload,
    );
    await _packetStore.savePacket(roomName, stored);
  }

  Future<void> _replayBufferedPackets(String roomName) async {
    final buffered = _packetsAwaitingGsk.remove(roomName);
    if (buffered != null) {
      for (final (packet, pubKey) in buffered) {
        await _processVerifiedPacket(roomName, packet, pubKey);
      }
    }
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
