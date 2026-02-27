import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cohortz/shared/utils/logging_service.dart';
import 'package:cohortz/shared/config/app_config.dart';
import 'package:cohortz/shared/security/group_identity_service.dart';

import '../group_connection_status.dart';
import '../sync_service.dart';
import 'invite_join_process.dart';
import '../../../../shared/utils/jwt_utils.dart';

/// Orchestrates group connection flows.
///
/// Intended responsibilities:
/// - Auto-join saved groups
/// - Connect existing known groups
/// - Delegate create/join flows to InviteJoinProcess
class GroupConnectionProcess {
  final SyncService _syncService;
  final InviteJoinProcess _inviteJoinProcess;
  final GroupIdentityService _groupIdentityService;
  final void Function(ConnectionProcessType) _onProcessStart;
  final void Function(int, StepStatus) _onStepUpdate;
  final void Function(String) _onProcessFail;
  final void Function() _onProcessComplete;

  GroupConnectionProcess({
    required SyncService syncService,
    required InviteJoinProcess inviteJoinProcess,
    required GroupIdentityService groupIdentityService,
    required void Function(ConnectionProcessType) onProcessStart,
    required void Function(int, StepStatus) onStepUpdate,
    required void Function(String) onProcessFail,
    required void Function() onProcessComplete,
  }) : _syncService = syncService,
       _inviteJoinProcess = inviteJoinProcess,
       _groupIdentityService = groupIdentityService,
       _onProcessStart = onProcessStart,
       _onStepUpdate = onStepUpdate,
       _onProcessFail = onProcessFail,
       _onProcessComplete = onProcessComplete;

  Future<void> connect(
    String roomName, {
    String inviteCode = '',
    String? localDisplayName,
  }) async {
    if (roomName.isEmpty) {
      throw Exception('Group Name is required.');
    }

    final cleanupRoomIds = <String>{roomName};

    try {
      final knownGroups = await _syncService.getKnownGroups();

      final knownDataRoom = knownGroups.firstWhere(
        (g) =>
            (g['isInviteRoom'] != 'true') &&
            (g['friendlyName'] == roomName || g['roomName'] == roomName),
        orElse: () => {},
      );

      // final displayName = knownDataRoom['friendlyName'] ?? roomName;

      // This is a "Connect" flow, which maps to AutoJoin steps logic-wise or maybe we need a "Connect" type?
      // Re-using AutoJoin type for generic connection for now, or assume generic "Connect"
      // Actually connect(roomName) is usually initiated by user tap.
      // Let's use autoJoin for now as the steps are similar.
      _onProcessStart(ConnectionProcessType.autoJoin);
      _onStepUpdate(0, StepStatus.completed); // "Checking saved" (simulated)
      _onStepUpdate(1, StepStatus.current); // Validating

      if (knownDataRoom.isNotEmpty && inviteCode.isEmpty) {
        final dataId = knownDataRoom['roomName'] ?? '';
        if (dataId.isNotEmpty) {
          final isHost = knownDataRoom['isHost'] == 'true';
          final existingIdentity = knownDataRoom['identity'];
          final profile = await _groupIdentityService.ensureForGroup(
            groupId: dataId,
            displayName: localDisplayName,
            fallbackIdentity: existingIdentity,
          );
          cleanupRoomIds.add(dataId);
          final token = await _fetchToken(dataId, profile.id);

          _onStepUpdate(1, StepStatus.completed);
          _onStepUpdate(2, StepStatus.current); // Connecting

          await _syncService.connect(
            token,
            dataId,
            identity: profile.id,
            friendlyName: roomName,
            isHost: isHost,
          );
          if (isHost) {
            await _inviteJoinProcess.ensureHostBootstrapAfterReconnect(
              roomName: dataId,
              hostId: profile.id,
              groupName: roomName,
            );
          }
          await _inviteJoinProcess.ensureMembershipAfterReconnect(
            roomName: dataId,
            memberId: profile.id,
          );

          if (dataId != roomName) {
            // Invite room join... invisible step?
            final inviteToken = await _fetchToken(roomName, profile.id);
            await _syncService.joinInviteRoom(
              inviteToken,
              roomName,
              identity: profile.id,
            );
          }
          _onStepUpdate(2, StepStatus.completed);
          _onProcessComplete();
        }
        return;
      }

      if (inviteCode.isEmpty) {
        if (localDisplayName == null || localDisplayName.trim().isEmpty) {
          throw Exception('Display name is required to create a group.');
        }
        final profile = await _groupIdentityService.ensureForGroup(
          groupId: roomName,
          displayName: localDisplayName,
        );
        // executeCreate will handle its own reporting if we pass the callbacks...
        await _inviteJoinProcess.executeCreate(roomName, profile: profile);
        _onProcessComplete();
      } else {
        if (localDisplayName == null || localDisplayName.trim().isEmpty) {
          throw Exception('Display name is required to join a group.');
        }
        final profile = await _groupIdentityService.ensureForGroup(
          groupId: roomName,
          displayName: localDisplayName,
        );
        await _inviteJoinProcess.executeJoin(
          roomName,
          inviteCode,
          profile: profile,
        );
        _onProcessComplete();
      }
    } catch (e) {
      if (e.toString().contains('DataRoomTransitionException')) {
        Log.i(
          'GroupConnectionProcess',
          'Data room transition successful. Completing process without cleanup.',
        );
        _onProcessComplete();
        return;
      }
      _onProcessFail(e.toString());
      await _cleanupRooms(cleanupRoomIds);
      rethrow;
    }
  }

  Future<bool> autoJoinSaved() async {
    Log.i('GroupConnectionProcess', 'Attempting auto-join...');
    var savedDetails = await _syncService.getSavedConnectionDetails();
    if (savedDetails == null) {
      Log.i(
        'GroupConnectionProcess',
        'No specific last group found. Checking known groups for fallback...',
      );
      final allGroups = await _syncService.getKnownGroups();
      final inviteGroups = _syncService.knownInviteGroups;

      // Combine and filter
      final candidates = <Map<String, String?>>[...allGroups, ...inviteGroups];

      if (candidates.isNotEmpty) {
        // Sort by lastJoined descending
        candidates.sort((a, b) {
          final aTime = DateTime.tryParse(a['lastJoined'] ?? '') ?? DateTime(0);
          final bTime = DateTime.tryParse(b['lastJoined'] ?? '') ?? DateTime(0);
          return bTime.compareTo(aTime);
        });

        final best = candidates.first;
        final roomName = best['roomName'];

        if (roomName != null && roomName.isNotEmpty) {
          Log.i(
            'GroupConnectionProcess',
            'Falling back to most recent group: $roomName',
          );
          // Construct savedDetails from this group
          savedDetails = {
            'roomName': roomName,
            'friendlyName': best['friendlyName'],
            'identity': best['identity'],
            'isInviteRoom': best['isInviteRoom'],
            'isHost': best['isHost'],
            'token': best['token'], // Might be null, will be refreshed below
          };
        }
      }
    }

    if (savedDetails == null) {
      Log.i(
        'GroupConnectionProcess',
        'No connection details available (saved or fallback).',
      );
      return false;
    }

    final roomName = savedDetails['roomName'] ?? '';
    Log.i('GroupConnectionProcess', 'Found saved room: $roomName');
    if (roomName.isEmpty) {
      Log.w('GroupConnectionProcess', 'Saved room name is empty.');
      return false;
    }

    _onProcessStart(ConnectionProcessType.autoJoin);
    _onStepUpdate(0, StepStatus.completed); // Checking saved groups (instant)
    var friendlyName = savedDetails['friendlyName'] ?? roomName;
    final savedIdentity = savedDetails['identity'] ?? '';
    final identity = savedIdentity.isNotEmpty
        ? savedIdentity
        : (await _groupIdentityService.ensureForGroup(groupId: roomName)).id;
    final isInviteRoom = savedDetails['isInviteRoom'] == 'true';
    var isHost = savedDetails['isHost'] == 'true';

    // Fallback: If friendlyName is still a UUID (matches roomName), try looking it up in known groups.
    // This handles cases where last_group_friendly_name was saved as UUID but we have the real name in store.
    if (friendlyName == roomName) {
      try {
        // Ensure groups are loaded
        final dataGroups = await _syncService.getKnownGroups();
        final inviteGroups = _syncService.knownInviteGroups;

        final allGroups = [...dataGroups, ...inviteGroups];
        final match = allGroups.firstWhere(
          (g) => g['roomName'] == roomName || g['dataRoomName'] == roomName,
          orElse: () => {},
        );

        if (match.isNotEmpty && match['friendlyName'] != null) {
          friendlyName = match['friendlyName']!;
        }
        if (!isHost && match.isNotEmpty && match['isHost'] == 'true') {
          isHost = true;
        }
      } catch (_) {
        // Ignore lookup errors, keep existing name
      }
    }

    if (!isHost) {
      try {
        final dataGroups = await _syncService.getKnownGroups();
        final known = dataGroups.firstWhere(
          (g) => g['roomName'] == roomName,
          orElse: () => {},
        );
        if (known.isNotEmpty && known['isHost'] == 'true') {
          isHost = true;
        }
      } catch (_) {}
    }

    _onStepUpdate(1, StepStatus.current); // Validating credentials (token)
    var token = savedDetails['token'];

    if (token == null || !JwtUtils.isValid(token)) {
      Log.w(
        'GroupConnectionProcess',
        'Saved token is missing, expired, or invalid. Fetching new token.',
      );
      try {
        token = await _fetchToken(roomName, identity);
      } catch (e) {
        _onProcessFail('Failed to refresh token: $e');
        return false;
      }
    }
    _onStepUpdate(1, StepStatus.completed);

    _onStepUpdate(2, StepStatus.current); // Connecting to mesh
    try {
      if (isInviteRoom) {
        // _onStatusChanged('Joining invite lobby for $friendlyName...');
        await _syncService.joinInviteRoom(
          token,
          roomName,
          identity: identity,
          setActive: false,
        );
      } else {
        // _onStatusChanged('Connecting to $friendlyName...');
        await _syncService.connect(
          token,
          roomName,
          identity: identity,
          isHost: isHost,
        );
      }

      if (!isInviteRoom) {
        if (isHost) {
          await _inviteJoinProcess.ensureHostBootstrapAfterReconnect(
            roomName: roomName,
            hostId: identity,
            groupName: friendlyName,
          );
        }
        await _groupIdentityService.ensureForGroup(
          groupId: roomName,
          fallbackIdentity: identity,
        );
        await _inviteJoinProcess.ensureMembershipAfterReconnect(
          roomName: roomName,
          memberId: identity,
        );
      }
      _onStepUpdate(2, StepStatus.completed);
      _onProcessComplete();
    } catch (e) {
      _onProcessFail(e.toString());
      rethrow;
    }

    return true;
  }

  Future<void> _cleanupRooms(Set<String> roomIds) async {
    for (final id in roomIds) {
      try {
        await _syncService.forgetGroup(id);
      } catch (_) {
        // Best-effort cleanup.
      }
    }
  }

  Future<String> _fetchToken(String room, String identity) async {
    final uri = Uri.parse(AppConfig.getTokenUrl(room, identity));
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['token'];
    }

    throw Exception('Failed to fetch token: ${response.body}');
  }
}
