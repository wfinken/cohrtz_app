import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

import 'package:flutter/foundation.dart';
import 'package:sql_crdt/sql_crdt.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/utils/logging_service.dart';
import '../../../shared/utils/sync_diagnostics.dart';

import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_service.dart';
import 'package:cohortz/src/generated/p2p_packet.pb.dart';
import '../runtime/crdt_service.dart';
import '../runtime/hlc_compat.dart';

/// Handles CRDT sync protocol operations.
///
/// This is extracted from SyncService for modularity and readability.
/// Manages sync requests, elections, and data exchange.
class SyncProtocol {
  final CrdtService _crdtService;
  final PermissionService _permissionService;
  final String Function(String roomName) getLocalParticipantIdForRoom;
  final Future<void> Function(String roomName, P2PPacket packet) broadcast;
  final Future<void> Function(
    String roomName,
    String targetId,
    P2PPacket packet,
  )
  sendSecure;
  final Future<SecretKey> Function(String roomName) getGroupKey;

  Timer? _electionTimer;
  bool _isElectionRunning = false;
  final _reliabilityScore = 1.0;
  final _random = Random();
  final Map<String, DateTime> _lastSyncRequest = {};
  final Map<String, DateTime> _lastConsistencyCheck = {};

  SyncProtocol({
    required CrdtService crdtService,
    required PermissionService permissionService,
    required this.getLocalParticipantIdForRoom,
    required this.broadcast,
    required this.sendSecure,
    required this.getGroupKey,
  }) : _crdtService = crdtService,
       _permissionService = permissionService;

  /// Initiates a sync request to the room.
  ///
  /// Includes our vector clock so responders can send only missing data.
  Future<void> requestSync(String roomName, {bool force = false}) async {
    if (!force) {
      final now = DateTime.now();
      final last = _lastSyncRequest[roomName];
      if (last != null && now.difference(last) < const Duration(seconds: 3)) {
        return;
      }
      _lastSyncRequest[roomName] = now;
    }

    Log.d('SyncProtocol', 'Broadcasting SYNC_REQ for $roomName...');
    SyncDiagnostics.emit(
      tag: 'SyncProtocol',
      message: 'Broadcasting SYNC_REQ for room sync.',
      roomName: roomName,
      kind: SyncDiagnosticKind.sync,
      direction: SyncDiagnosticDirection.outbound,
    );

    final localVc = await _crdtService.getVectorClock(roomName);
    final vcPayload = utf8.encode(jsonEncode(localVc));

    final reqPacket = P2PPacket()
      ..type = P2PPacket_PacketType.SYNC_REQ
      ..requestId = const Uuid().v4()
      ..senderId = getLocalParticipantIdForRoom(roomName)
      ..payload = vcPayload;

    await broadcast(roomName, reqPacket);
  }

  /// Handles an incoming SYNC_REQ packet.
  ///
  /// Starts an election to determine who responds (avoids duplicates).
  void handleSyncReq(String roomName, P2PPacket packet, VoidCallback onWin) {
    if (_isElectionRunning) return;

    final localId = getLocalParticipantIdForRoom(roomName);
    Log.d(
      'SyncProtocol',
      'Checking SYNC_REQ ($roomName): Sender=${packet.senderId}, Local=$localId',
    );

    if (packet.senderId == localId) {
      Log.d('SyncProtocol', 'Ignoring own SYNC_REQ');
      return;
    }

    Log.i(
      'SyncProtocol',
      'Received SYNC_REQ from ${packet.senderId} in $roomName. Starting election.',
    );

    _isElectionRunning = true;

    const baseTimeMs = 100;
    final jitter = _random.nextInt(50);
    final delayMs = (baseTimeMs / _reliabilityScore) + jitter;

    Log.d('SyncProtocol', 'Starting election timer for ${delayMs}ms');

    _electionTimer = Timer(Duration(milliseconds: delayMs.toInt()), onWin);
  }

  /// Handles an incoming SYNC_CLAIM packet.
  ///
  /// Cancels our election timer if someone else claimed the sync.
  void handleSyncClaim(String roomName, P2PPacket packet) {
    if (!_isElectionRunning) return;
    if (packet.senderId == getLocalParticipantIdForRoom(roomName)) return;

    Log.i(
      'SyncProtocol',
      'Election won by ${packet.senderId}. Cancelling timer.',
    );
    cancelElection();
  }

  /// Called when we win the election.
  ///
  /// Claims the sync and sends data to the requester.
  Future<void> winElection(
    String roomName,
    String requestId,
    String requesterId,
    VectorClock? remoteVc,
  ) async {
    try {
      if (!_isElectionRunning) return;

      Log.i('SyncProtocol', 'I won the election for $roomName! Claiming...');

      final claimPacket = P2PPacket()
        ..type = P2PPacket_PacketType.SYNC_CLAIM
        ..requestId = requestId
        ..senderId = getLocalParticipantIdForRoom(roomName);

      await broadcast(roomName, claimPacket);
      cancelElection();

      Log.d(
        'SyncProtocol',
        'Sending sync data to $requesterId in $roomName...',
      );

      final changeset = remoteVc != null
          ? await _crdtService.getChangesetFromVector(roomName, remoteVc)
          : await _crdtService.getChangeset(roomName);

      Log.d('SyncProtocol', 'Changeset contains ${changeset.length} tables.');

      final jsonString = jsonEncode(
        changeset,
        toEncodable: (nonEncodable) {
          if (nonEncodable is Hlc) return nonEncodable.toString();
          return nonEncodable;
        },
      );

      final payload = utf8.encode(jsonString);
      Log.d('SyncProtocol', 'Payload size: ${payload.length} bytes');

      final dataPacket = P2PPacket()
        ..type = P2PPacket_PacketType.DATA_CHUNK
        ..requestId = const Uuid().v4()
        ..senderId = getLocalParticipantIdForRoom(roomName)
        ..payload = payload;

      await sendSecure(roomName, requesterId, dataPacket);
      SyncDiagnostics.emit(
        tag: 'SyncProtocol',
        message: 'Sent DATA_CHUNK sync response to $requesterId.',
        roomName: roomName,
        peerId: requesterId,
        kind: SyncDiagnosticKind.sync,
        direction: SyncDiagnosticDirection.outbound,
        bytes: payload.length,
      );
    } catch (e, stack) {
      Log.e('SyncProtocol', 'Error in winElection', e, stack);
    }
  }

  /// Merges an incoming data chunk into the local CRDT.
  Future<void> mergeDataChunk(String roomName, P2PPacket packet) async {
    Log.i(
      'SyncProtocol',
      'Data chunk received in $roomName. Merging into CRDT.',
    );

    try {
      final jsonString = utf8.decode(packet.payload);
      final Map<String, dynamic> decoded = jsonDecode(jsonString);

      Log.d(
        'PacketHandler',
        'Merging changeset with tables: ${decoded.keys.toList()}',
      );
      if (decoded.containsKey('user_profiles')) {
        final profiles = decoded['user_profiles'] as List;
        Log.d('PacketHandler', 'user_profiles count: ${profiles.length}');
      }

      final touchesRoleOrMembers = decoded.keys.any(
        (key) => key == 'roles' || key == 'members',
      );
      final touchesLogicalGroups = decoded.keys.contains('logical_groups');
      if (touchesRoleOrMembers || touchesLogicalGroups) {
        final isBootstrap = await _permissionService.isBootstrapState(roomName);
        if (!isBootstrap) {
          final senderId = packet.senderId;
          if (touchesRoleOrMembers) {
            final canManageRoles = await _permissionService.hasPermission(
              roomName,
              senderId,
              PermissionFlags.manageRoles,
            );
            if (!canManageRoles) {
              Log.w(
                'SyncProtocol',
                'RBAC violation: $senderId attempted role/member changes without manageRoles.',
              );
              return;
            }
          }

          if (touchesLogicalGroups) {
            final canManageRoles = await _permissionService.hasPermission(
              roomName,
              senderId,
              PermissionFlags.manageRoles,
            );
            final canManageMembers = await _permissionService.hasPermission(
              roomName,
              senderId,
              PermissionFlags.manageMembers,
            );
            if (!(canManageRoles && canManageMembers)) {
              Log.w(
                'SyncProtocol',
                'RBAC violation: $senderId attempted logical_groups changes without manageRoles+manageMembers.',
              );
              return;
            }
          }
        }
      }

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
      Log.i('SyncProtocol', 'Merge successful in $roomName.');
      SyncDiagnostics.emit(
        tag: 'SyncProtocol',
        message: 'Merged DATA_CHUNK from ${packet.senderId}.',
        roomName: roomName,
        peerId: packet.senderId,
        kind: SyncDiagnosticKind.sync,
        direction: SyncDiagnosticDirection.inbound,
        bytes: packet.payload.length,
        isSyncCompletion: true,
      );
    } catch (e) {
      Log.e('SyncProtocol', 'Error merging data chunk', e);
    }
  }

  /// Parses a vector clock from a SYNC_REQ payload.
  VectorClock? parseVectorClock(P2PPacket packet) {
    try {
      if (packet.payload.isNotEmpty) {
        final Map<String, dynamic> json = jsonDecode(
          utf8.decode(packet.payload),
        );
        return json.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (e) {
      Log.w('SyncProtocol', 'Error parsing remote VC: $e');
    }
    return null;
  }

  /// Cancels any running election.
  void cancelElection() {
    _electionTimer?.cancel();
    _electionTimer = null;
    _isElectionRunning = false;
  }

  /// Broadcasts a consistency check to verify sync integrity.
  Future<void> broadcastConsistencyCheck(String roomName) async {
    try {
      final now = DateTime.now();
      final last = _lastConsistencyCheck[roomName];
      if (last != null && now.difference(last) < const Duration(seconds: 2)) {
        return;
      }
      _lastConsistencyCheck[roomName] = now;

      final diag = await _crdtService.getDiagnostics(roomName);
      final payload = utf8.encode(jsonEncode(diag));

      final packet = P2PPacket()
        ..type = P2PPacket_PacketType.CONSISTENCY_CHECK
        ..requestId = const Uuid().v4()
        ..senderId = getLocalParticipantIdForRoom(roomName)
        ..payload = payload;

      await broadcast(roomName, packet);
    } catch (e) {
      Log.e(
        'SyncProtocol',
        'Error broadcasting consistency check for $roomName',
        e,
      );
    }
  }

  void dispose() {
    _electionTimer?.cancel();
    _electionTimer = null;
  }
}
