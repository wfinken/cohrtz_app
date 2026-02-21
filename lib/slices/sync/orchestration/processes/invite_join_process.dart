import 'dart:async';
import 'dart:convert';
import 'package:cohortz/shared/utils/logging_service.dart';
import 'package:cohortz/shared/utils/jwt_utils.dart';

import 'package:uuid/uuid.dart';
import 'package:cohortz/shared/config/app_config.dart';
import 'package:http/http.dart' as http;

import 'package:cohortz/shared/security/group_identity_service.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/dashboard_shell/models/user_model.dart';
import 'package:cohortz/slices/permissions_feature/state/member_repository.dart';
import 'package:cohortz/slices/permissions_feature/state/role_repository.dart';
import 'package:cohortz/slices/permissions_feature/models/member_model.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';
import '../sync_service.dart';
import '../../runtime/key_manager.dart';
import '../../runtime/crdt_service.dart';
import '../../runtime/hybrid_time_service.dart';
import 'sync_process.dart';
import '../group_connection_status.dart';

/// Orchestrates the invite join flow.
///
/// Intended responsibilities:
/// - Join invite room
/// - Run invite handshake
/// - Transition to data room
/// - Trigger initial sync
class InviteJoinProcess implements SyncProcess {
  final SyncService _syncService;
  final KeyManager _keyManager;
  final GroupIdentityService _groupIdentityService;
  final CrdtService _crdtService;
  final HybridTimeService _hybridTimeService;
  final void Function(ConnectionProcessType) _onProcessStart;
  final void Function(int, StepStatus) _onStepUpdate;
  final Uuid _uuid = const Uuid();

  InviteJoinProcess({
    required SyncService syncService,
    required KeyManager keyManager,
    required GroupIdentityService groupIdentityService,
    required CrdtService crdtService,
    required HybridTimeService hybridTimeService,
    required void Function(ConnectionProcessType) onProcessStart,
    required void Function(int, StepStatus) onStepUpdate,
  }) : _syncService = syncService,
       _keyManager = keyManager,
       _groupIdentityService = groupIdentityService,
       _crdtService = crdtService,
       _hybridTimeService = hybridTimeService,
       _onProcessStart = onProcessStart,
       _onStepUpdate = onStepUpdate;

  Future<String> _fetchToken(String room, String identity) async {
    final uri = Uri.parse(AppConfig.getTokenUrl(room, identity));
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final token = body['token'];
      try {
        final payload = JwtUtils.decodePayload(token);
        Log.d(
          'InviteJoinProcess',
          'Fetched token for $room / $identity. Issuer: ${payload['iss']}',
        );
      } catch (_) {}
      return token;
    }

    throw Exception('Failed to fetch token: ${response.body}');
  }

  Future<void> executeCreate(
    String roomName, {
    required UserProfile profile,
  }) async {
    // Start Process
    _onProcessStart(ConnectionProcessType.create);
    _onStepUpdate(0, StepStatus.current); // Checking invite room

    // Probe invite room to see if it exists.
    final inviteToken = await _fetchToken(roomName, profile.id);
    await _syncService.joinInviteRoom(
      inviteToken,
      roomName,
      identity: profile.id,
    );
    _onStepUpdate(0, StepStatus.completed);

    await Future.delayed(const Duration(seconds: 1));

    _onStepUpdate(1, StepStatus.current); // Generating data room
    final dataRoomId = _uuid.v7();
    final dataRoomProfile = await _groupIdentityService.ensureForGroup(
      groupId: dataRoomId,
      displayName: profile.displayName,
      fallbackIdentity: profile.id,
    );

    final groupSettings = GroupSettings(
      id: 'group_settings',
      name: roomName,
      createdAt: _hybridTimeService.getAdjustedTimeLocal(),
      logicalTime: _hybridTimeService.nextLogicalTime(),
      dataRoomName: dataRoomId,
      ownerId: dataRoomProfile.id,
    );

    final dataToken = await _fetchToken(dataRoomId, dataRoomProfile.id);
    _onStepUpdate(1, StepStatus.completed);

    _onStepUpdate(
      2,
      StepStatus.current,
    ); // Setting up permissions (and connecting)
    await _syncService.connect(
      dataToken,
      dataRoomId,
      identity: dataRoomProfile.id,
      friendlyName: roomName,
      isHost: true,
    );

    final dataRoomRepo = DashboardRepository(
      _crdtService,
      dataRoomId,
      _hybridTimeService,
    );
    final roleRepo = RoleRepository(_crdtService, dataRoomId);
    final memberRepo = MemberRepository(_crdtService, dataRoomId);

    final ownerRole = Role(
      id: 'role:${_uuid.v7()}',
      groupId: dataRoomId,
      name: 'Owner',
      color: 0xFFFFD700,
      position: 100,
      permissions: PermissionFlags.administrator,
      isHoisted: true,
    );
    final memberRole = Role(
      id: 'role:${_uuid.v7()}',
      groupId: dataRoomId,
      name: 'Member',
      color: 0xFF9E9E9E,
      position: 10,
      permissions: PermissionFlags.defaultMember,
    );

    await dataRoomRepo.saveUserProfile(dataRoomProfile);
    await dataRoomRepo.saveGroupSettings(groupSettings);
    await roleRepo.saveRole(ownerRole);
    await roleRepo.saveRole(memberRole);
    await memberRepo.saveMember(
      GroupMember(id: dataRoomProfile.id, roleIds: [ownerRole.id]),
    );

    _onStepUpdate(2, StepStatus.completed);
    _onStepUpdate(3, StepStatus.current); // Finalizing
    // ... any final work?
    _onStepUpdate(3, StepStatus.completed);
  }

  Future<void> executeJoin(
    String roomName,
    String inviteCode, {
    required UserProfile profile,
  }) async {
    if (inviteCode.isEmpty) {
      throw Exception('Invite code is required to join a group.');
    }

    _onProcessStart(ConnectionProcessType.join);
    _onStepUpdate(0, StepStatus.current); // Joining invite room

    final token = await _fetchToken(roomName, profile.id);

    try {
      await _syncService.connect(
        token,
        roomName,
        identity: profile.id,
        inviteCode: inviteCode,
        isHost: false,
      );
      _onStepUpdate(0, StepStatus.completed);

      // Note: _syncService.connect internally handles "Handshake" (Invite Protocol).
      // But we don't have granular callbacks there.
      // We assume if it returns, handshake is done?
      // Actually connect throws DataRoomTransitionException if handshake succeeds.
      // So checking off step 1 (Handshaking) happens in the catch block?
      // Step 1: Handshaking. SyncService does this.
    } catch (e) {
      if (e is DataRoomTransitionException) {
        _onStepUpdate(0, StepStatus.completed);
        _onStepUpdate(
          1,
          StepStatus.completed,
        ); // Handshake done implicitly by exception

        _onStepUpdate(2, StepStatus.current); // Transitioning to secure mesh
        await _keyManager.clearGroupKey(e.dataRoomUUID);
        final dataRoomProfile = await _groupIdentityService.ensureForGroup(
          groupId: e.dataRoomUUID,
          displayName: profile.displayName,
          fallbackIdentity: profile.id,
        );
        final dataToken = await _fetchToken(e.dataRoomUUID, dataRoomProfile.id);

        await _syncService.connect(
          dataToken,
          e.dataRoomUUID,
          identity: dataRoomProfile.id,
          friendlyName: roomName,
          isHost: false,
        );
        _onStepUpdate(2, StepStatus.completed);

        _onStepUpdate(3, StepStatus.current); // Verifying
        final dataRoomRepo = DashboardRepository(
          _crdtService,
          e.dataRoomUUID,
          _hybridTimeService,
        );
        await dataRoomRepo.saveUserProfile(dataRoomProfile);

        _onStepUpdate(3, StepStatus.completed);
        return;
      }
      // If we are here, error occurred.
      // Let parent handle failProcess
      rethrow;
    }
  }

  @override
  Future<void> execute() async {
    throw UnimplementedError(
      'Use executeCreate/executeJoin for invite orchestration.',
    );
  }
}
