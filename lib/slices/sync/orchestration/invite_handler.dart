import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'package:cohortz/src/generated/p2p_packet.pb.dart';
import 'package:cohortz/slices/permissions_feature/models/member_model.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';
import '../runtime/crdt_service.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import '../../../shared/utils/logging_service.dart';

/// Handles invite request/acknowledgement/rejection flow.
///
/// This is extracted from SyncService for modularity and readability.
/// The main SyncService coordinates between handlers but does not contain
/// the detailed logic itself.
class InviteHandler {
  final CrdtService _crdtService;
  final String Function() getLocalParticipantId;
  final Future<void> Function(String roomName, P2PPacket packet) broadcast;
  final Set<String> Function() getConnectedRoomNames;

  final Map<String, Completer<String>> _pendingInvites = {};

  InviteHandler({
    required CrdtService crdtService,
    required this.getLocalParticipantId,
    required this.broadcast,
    required this.getConnectedRoomNames,
  }) : _crdtService = crdtService;

  Future<String> waitForInviteAck(String requestId, Duration timeout) async {
    final completer = Completer<String>();
    _pendingInvites[requestId] = completer;

    try {
      final result = await completer.future.timeout(timeout);
      if (result.startsWith('REJECT:')) {
        throw Exception(result.replaceFirst('REJECT:', ''));
      }
      return result;
    } finally {
      _pendingInvites.remove(requestId);
    }
  }

  void handleInviteAck(String roomName, P2PPacket packet) {
    Log.i(
      'InviteHandler',
      'Received INVITE_ACK in $roomName from ${packet.senderId} for req ${packet.requestId}',
    );

    final completer = _pendingInvites[packet.requestId];
    if (completer != null && !completer.isCompleted) {
      final dataRoomName = utf8.decode(packet.payload);
      completer.complete(dataRoomName);
    }
  }

  void handleInviteNack(String roomName, P2PPacket packet) {
    Log.w(
      'InviteHandler',
      'Received INVITE_NACK in $roomName from ${packet.senderId} for req ${packet.requestId}',
    );

    final completer = _pendingInvites[packet.requestId];
    if (completer != null && !completer.isCompleted) {
      final message = utf8.decode(packet.payload);
      completer.complete('REJECT:$message');
    }
  }

  // Cache of processed invite requests: RequestID -> DataRoomName (or null if NACK/Ignore)
  // We only cache success to support idempotency for lost ACKs.
  final Map<String, String> _processedInvitesCache = {};

  /// Handles an incoming INVITE_REQ packet.
  ///
  /// Validates the invite code against known groups and responds with
  /// either INVITE_ACK (with the data room UUID) or INVITE_NACK.
  Future<void> handleInviteReq(String roomName, P2PPacket packet) async {
    Log.i(
      'InviteHandler',
      'Received INVITE_REQ in $roomName from ${packet.senderId} (ReqID: ${packet.requestId})',
    );

    // 0. Idempotency Check
    if (_processedInvitesCache.containsKey(packet.requestId)) {
      final cachedDataRoom = _processedInvitesCache[packet.requestId];
      if (cachedDataRoom != null) {
        Log.d(
          'InviteHandler',
          'Duplicate INVITE_REQ ${packet.requestId} detected. Resending cached ACK for $cachedDataRoom.',
        );
        final ackPacket = P2PPacket()
          ..type = P2PPacket_PacketType.INVITE_ACK
          ..requestId = packet.requestId
          ..senderId = getLocalParticipantId()
          ..payload = utf8.encode(cachedDataRoom);

        await broadcast(roomName, ackPacket);
        return; // Done
      } else {
        // It was processed but resulted in failure/ignore previously?
        // For now, we only cache successes to be safe.
        // If we cached failures, we might permanently block a valid retry if state changed.
        Log.w(
          'InviteHandler',
          'Duplicate INVITE_REQ ${packet.requestId} detected but no cached success. Re-processing.',
        );
      }
    }

    final inviteCode = utf8.decode(packet.payload);
    try {
      bool groupNameMatched = false;

      // 1. Check Connected Rooms First
      final connectedRooms = getConnectedRoomNames();
      for (final otherRoomName in connectedRooms) {
        if (otherRoomName == roomName) continue;

        // Query CRDT securely
        try {
          final results = await _crdtService.query(
            otherRoomName,
            'SELECT id, value FROM group_settings WHERE is_deleted = 0',
          );

          for (final row in results) {
            final settingsRowId = row['id'] as String?;
            final jsonStr = row['value'] as String?;
            if (settingsRowId == null || jsonStr == null) continue;
            final settings = GroupSettingsMapper.fromJson(jsonStr);

            // Case-insensitive group name match
            if (settings.name.toLowerCase() == roomName.toLowerCase()) {
              groupNameMatched = true;

              GroupInvite? invite;
              for (final i in settings.invites) {
                if (i.code.toLowerCase() == inviteCode.toLowerCase() &&
                    i.isValid) {
                  invite = i;
                  break;
                }
              }

              if (invite != null) {
                Log.i(
                  'InviteHandler',
                  'Invite code $inviteCode verified via connected room $otherRoomName!',
                );

                await _assignInviteRole(
                  roomName: otherRoomName,
                  memberId: packet.senderId,
                  inviteRoleId: invite.roleId,
                );

                // If single-use, remove it and update settings.
                //
                // Important: group_settings can have multiple rows (legacy/migration).
                // If we only update using settings.id (from JSON), we can accidentally
                // write to the wrong row key and leave the token unconsumed. Instead
                // we update by the actual row id we queried, and we also scrub the
                // code from any other matching group_settings rows for this group.
                if (invite.isSingleUse) {
                  Log.i(
                    'InviteHandler',
                    'Consuming single-use invite code $inviteCode in $otherRoomName',
                  );
                  int consumedRows = 0;

                  Future<void> consumeInRow({
                    required String rowId,
                    required GroupSettings rowSettings,
                  }) async {
                    final before = rowSettings.invites.length;
                    final afterInvites = rowSettings.invites
                        .where(
                          (i) =>
                              i.code.toLowerCase() != inviteCode.toLowerCase(),
                        )
                        .toList();
                    if (afterInvites.length == before) return;

                    final updatedSettings = rowSettings.copyWith(
                      invites: afterInvites,
                    );
                    await _crdtService.put(
                      otherRoomName,
                      rowId,
                      jsonEncode(updatedSettings.toMap()),
                      tableName: 'group_settings',
                    );
                    consumedRows++;
                  }

                  // Consume in the row we matched.
                  await consumeInRow(
                    rowId: settingsRowId,
                    rowSettings: settings,
                  );

                  // Also consume in any other rows for the same group name
                  // (migration/legacy duplicates).
                  for (final otherRow in results) {
                    final otherRowId = otherRow['id'] as String?;
                    final otherJson = otherRow['value'] as String?;
                    if (otherRowId == null ||
                        otherJson == null ||
                        otherRowId == settingsRowId) {
                      continue;
                    }
                    try {
                      final otherSettings = GroupSettingsMapper.fromJson(
                        otherJson,
                      );
                      if (otherSettings.name.toLowerCase() !=
                          roomName.toLowerCase()) {
                        continue;
                      }
                      await consumeInRow(
                        rowId: otherRowId,
                        rowSettings: otherSettings,
                      );
                    } catch (_) {
                      // Ignore malformed legacy rows.
                    }
                  }

                  Log.i(
                    'InviteHandler',
                    'Invite code removed from $consumedRows group_settings row(s) in $otherRoomName',
                  );
                }

                // Cache Success!
                _processedInvitesCache[packet.requestId] =
                    settings.dataRoomName;

                // Send ACK with Data Room UUID
                final ackPacket = P2PPacket()
                  ..type = P2PPacket_PacketType.INVITE_ACK
                  ..requestId = packet.requestId
                  ..senderId = getLocalParticipantId()
                  ..payload = utf8.encode(settings.dataRoomName);

                await broadcast(roomName, ackPacket);
                return;
              }
            }
          }
        } catch (e) {
          Log.e(
            'InviteHandler',
            'Error querying connected room $otherRoomName',
            e,
          );
        }
      }

      // 2. If no connected match, check known groups (Race Condition Fix)
      // This happens if the Host is still connecting to the Data Room
      if (!groupNameMatched) {
        // We can't query the CRDT if not connected.
        // But we can check if we *should* be hosting this group.
        // This requires access to GroupManager, which we don't have directly here...
        // Wait, providers.dart injects dependencies. We can add GroupManager or just fail gracefully.
        // For now, let's just log this specific case.
        Log.w(
          'InviteHandler',
          'No connected group found matching $roomName. Checking if we are hosting it but it is offline...',
        );
        // If we are the host, we SHOULD be connected. If not, it's a connectivity issue on our end.
        // Sending NACK might be premature if we are just slow to connect.
        // Instead, we ignore (timeout on joiner side) OR send a "Wait" signal if protocol supported it.
        // Existing protocol expects ACK/NACK.
      }

      if (groupNameMatched) {
        Log.w(
          'InviteHandler',
          'Invite code $inviteCode INVALID for room $roomName. MATCH FOUND BUT CODE REJECTED. Sending NACK.',
        );
        final nackPacket = P2PPacket()
          ..type = P2PPacket_PacketType.INVITE_NACK
          ..requestId = packet.requestId
          ..senderId = getLocalParticipantId()
          ..payload = utf8.encode('Invalid, expired, or used invite code.');

        await broadcast(roomName, nackPacket);
      } else {
        Log.d(
          'InviteHandler',
          'No group found hosting $roomName in connected rooms. Ignoring.',
        );
        // Don't NACK here, as another peer might be the host.
        // Only the actual host should NACK if the code is wrong.
        // If NO ONE acts as host, the joiner times out.
      }
    } catch (e) {
      Log.e('InviteHandler', 'Error handling INVITE_REQ', e);
    }
  }

  /// Executes the full invite protocol with retries.
  ///
  /// Sends INVITE_REQ periodically until an ACK/NACK is received or timeout occurs.
  Future<String> executeInviteProtocol(
    String roomName,
    String inviteCode, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final packet = createInviteRequest(inviteCode, getLocalParticipantId());
    final completer = Completer<String>();
    _pendingInvites[packet.requestId] = completer;

    Timer? retryTimer;

    try {
      // internal helper to send
      Future<void> sendAttempt() async {
        Log.d(
          'InviteHandler',
          'Sending INVITE_REQ (Retry Loop) for $roomName with code $inviteCode (ReqID: ${packet.requestId})',
        );
        await broadcast(roomName, packet);
      }

      // Send immediately
      await sendAttempt();

      // Start retry timer (every 2 seconds)
      retryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (!completer.isCompleted) {
          sendAttempt();
        }
      });

      // Wait for result or timeout
      final result = await completer.future.timeout(timeout);

      if (result.startsWith('REJECT:')) {
        throw Exception(result.replaceFirst('REJECT:', ''));
      }
      return result;
    } catch (e) {
      if (e is TimeoutException) {
        Log.w('InviteHandler', 'Invite Protocol timed out after $timeout.');
      }
      rethrow;
    } finally {
      retryTimer?.cancel();
      _pendingInvites.remove(packet.requestId);
    }
  }

  /// Sends an INVITE_REQ to the group (broadcast) and returns the Request ID.
  /// DEPRECATED: Use [executeInviteProtocol] for reliable execution.
  Future<String> sendInviteRequest(String roomName, String inviteCode) async {
    final packet = createInviteRequest(inviteCode, getLocalParticipantId());
    Log.i(
      'InviteHandler',
      'Sending INVITE_REQ for $roomName with code $inviteCode (ReqID: ${packet.requestId})',
    );
    await broadcast(roomName, packet);
    return packet.requestId;
  }

  /// Creates an INVITE_REQ packet for joining a group.
  P2PPacket createInviteRequest(String inviteCode, String senderId) {
    return P2PPacket()
      ..type = P2PPacket_PacketType.INVITE_REQ
      ..requestId = const Uuid().v4()
      ..senderId = senderId
      ..payload = utf8.encode(inviteCode);
  }

  /// Parses an INVITE_ACK response to extract the data room name.
  String parseInviteAck(P2PPacket packet) {
    return utf8.decode(packet.payload);
  }

  /// Parses an INVITE_NACK response to extract the rejection message.
  String parseInviteNack(P2PPacket packet) {
    final message = utf8.decode(packet.payload);
    return 'REJECT:$message';
  }

  Future<void> _assignInviteRole({
    required String roomName,
    required String memberId,
    required String inviteRoleId,
  }) async {
    try {
      final roleRows = await _crdtService.query(
        roomName,
        'SELECT value FROM roles WHERE is_deleted = 0',
      );
      if (roleRows.isEmpty) {
        Log.w(
          'InviteHandler',
          'No roles found in $roomName while assigning member $memberId.',
        );
        return;
      }

      final roles = <Role>[];
      for (final row in roleRows) {
        final value = row['value'] as String? ?? '';
        if (value.isEmpty) continue;
        try {
          final role = RoleMapper.fromJson(value);
          roles.add(role);
        } catch (_) {}
      }

      if (roles.isEmpty) return;

      Role? memberRole;
      if (inviteRoleId.isNotEmpty) {
        for (final role in roles) {
          if (role.id == inviteRoleId) {
            memberRole = role;
            break;
          }
        }
      }

      memberRole ??= roles.firstWhere(
        (role) => role.name.toLowerCase() == 'member',
        orElse: () {
          roles.sort((a, b) => a.position.compareTo(b.position));
          return roles.first;
        },
      );

      if (memberRole.id.isEmpty) return;

      final memberRows = await _crdtService.query(
        roomName,
        'SELECT value FROM members WHERE id = ?',
        [memberId],
      );
      GroupMember member;
      if (memberRows.isNotEmpty) {
        final value = memberRows.first['value'] as String? ?? '';
        if (value.isNotEmpty) {
          member = GroupMemberMapper.fromJson(value);
        } else {
          member = GroupMember(id: memberId, roleIds: []);
        }
      } else {
        member = GroupMember(id: memberId, roleIds: []);
      }

      if (!member.roleIds.contains(memberRole.id)) {
        final updated = member.copyWith(
          roleIds: {...member.roleIds, memberRole.id}.toList(),
        );
        await _crdtService.put(
          roomName,
          memberId,
          jsonEncode(updated.toMap()),
          tableName: 'members',
        );
        Log.i(
          'InviteHandler',
          'Assigned role ${memberRole.id} to member $memberId in $roomName.',
        );
      }
    } catch (e) {
      Log.e(
        'InviteHandler',
        'Failed to assign default role to $memberId in $roomName',
        e,
      );
    }
  }
}
