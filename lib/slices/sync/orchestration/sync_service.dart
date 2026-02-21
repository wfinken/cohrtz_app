import 'dart:async';
import 'package:flutter/widgets.dart' hide ConnectionState;
import 'package:livekit_client/livekit_client.dart';
import 'package:cohortz/shared/config/app_config.dart';
import 'package:cryptography/cryptography.dart';

import '../runtime/connection_manager.dart';
import '../runtime/group_manager.dart';
import '../runtime/key_manager.dart';
import '../../../shared/utils/logging_service.dart';

import 'invite_handler.dart';
import 'processes/network_recovery_process.dart';

/// Thrown when an invite transition to a data room is successful.
class DataRoomTransitionException implements Exception {
  final String dataRoomUUID;
  DataRoomTransitionException(this.dataRoomUUID);
  @override
  String toString() => 'DataRoomTransitionException: $dataRoomUUID';
}

/// Thrown when an invite is rejected.
class InviteRejectedException implements Exception {
  final String message;
  InviteRejectedException(this.message);
  @override
  String toString() => 'InviteRejectedException: $message';
}

/// Thrown when attempting to join a group that is already known/connected.
class GroupExistsException implements Exception {
  final String message;
  GroupExistsException(this.message);
  @override
  String toString() => 'GroupExistsException: $message';
}

/// The main entry point for sync functionality, refactored to delegate logic
/// to specialized managers while maintaining the existing public API for the UI.
class SyncService extends ChangeNotifier with WidgetsBindingObserver {
  final ConnectionManager _connectionManager;
  final GroupManager _groupManager;
  final KeyManager _keyManager;
  final InviteHandler _inviteHandler;
  final NetworkRecoveryProcess _networkRecoveryProcess;

  // Expose internal state for UI to consume
  String? get activeRoomName => _connectionManager.activeRoomName;
  String? get currentRoomName => _connectionManager.activeRoomName;
  String? get localParticipantId => _connectionManager.localParticipantId;
  String? get identity => _connectionManager.localParticipantId; // Alias

  bool get isActiveRoomConnected => _connectionManager.isActiveRoomConnected();
  bool get isActiveRoomConnecting =>
      _connectionManager.isActiveRoomConnecting();
  bool get isConnected => _connectionManager.isAnyRoomConnected;

  Map<String, RemoteParticipant> get remoteParticipants {
    final room = activeRoomName;
    if (room == null) return {};
    return _connectionManager.getRemoteParticipants(room);
  }

  SyncService({
    required ConnectionManager connectionManager,
    required GroupManager groupManager,
    required KeyManager keyManager,
    required InviteHandler inviteHandler,
    required NetworkRecoveryProcess networkRecoveryProcess,
  }) : _connectionManager = connectionManager,
       _groupManager = groupManager,
       _keyManager = keyManager,
       _inviteHandler = inviteHandler,
       _networkRecoveryProcess = networkRecoveryProcess {
    WidgetsBinding.instance.addObserver(this);

    // Proxy changes from managers to our listeners
    _connectionManager.addListener(notifyListeners);
    _connectionManager.startJanitors();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionManager.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // _networkRecoveryProcess.suspend();
    } else if (state == AppLifecycleState.resumed) {
      _networkRecoveryProcess.restore();
    }
  }

  Future<void> connect(
    String token,
    String roomName, {
    String? identity,
    String? inviteCode,
    String? friendlyName,
    String? dataRoomName,
    bool isHost = false,
    bool setActive = true,
  }) async {
    final actualDataRoomName = dataRoomName ?? roomName;
    final isInviteJoin = inviteCode != null && inviteCode.isNotEmpty && !isHost;

    if (isInviteJoin) {
      await _connectionManager.joinInviteRoom(
        token,
        roomName,
        identity: identity,
        setActive: false,
      );
    } else {
      // Connect to the room (LiveKit)
      await _connectionManager.connect(
        token,
        roomName,
        dataRoomName: actualDataRoomName,
        identity: identity,
        inviteCode: inviteCode,
        friendlyName: friendlyName,
        isHost: isHost,
        setActive: setActive,
      );
    }

    // If joining with an invite code (and we are NOT the host), perform the Invite Handshake
    if (isInviteJoin) {
      Log.i('SyncService', 'Initiating Invite Protocol for $roomName...');

      try {
        // Wait briefly for peers to discover and handshake
        // (HandshakeHandler handles the base connectivity, we need peers to be ready to receive broadcast)
        await Future.delayed(const Duration(milliseconds: 1000));

        final dataRoomId = await _inviteHandler.executeInviteProtocol(
          roomName,
          inviteCode,
          timeout: const Duration(seconds: 15),
        );

        Log.i('SyncService', 'Invite accepted! Data Room: $dataRoomId');
        // Transition logic:
        // We are currently in an invite room and should now switch to the real data room.
        throw DataRoomTransitionException(dataRoomId);
      } catch (e) {
        if (e is DataRoomTransitionException) {
          Log.i(
            'SyncService',
            'Invite Protocol Successful. Transitioning to Data Room: ${e.dataRoomUUID}',
          );
          rethrow;
        }
        Log.e('SyncService', 'Invite Protocol Failed', e);
        if (e is TimeoutException) {
          throw InviteRejectedException('Host did not respond in time.');
        } else if (e.toString().contains('REJECT:')) {
          throw InviteRejectedException(
            e.toString().replaceFirst('REJECT:', ''),
          );
        }
        rethrow;
      }
    }
  }

  Future<void> connectAllKnownGroups() async {
    await _networkRecoveryProcess.restore();
  }

  Future<void> disconnect() => _connectionManager.disconnectAll();

  Future<void> joinInviteRoom(
    String token,
    String groupName, {
    String? identity,
    bool setActive = false,
  }) => _connectionManager.joinInviteRoom(
    token,
    groupName,
    identity: identity,
    setActive: setActive,
  );

  Future<List<Map<String, String?>>> getKnownGroups() async =>
      _groupManager.getKnownGroups();

  List<Map<String, String?>> get knownGroups => _groupManager.knownGroups;
  List<Map<String, String?>> get knownInviteGroups =>
      _groupManager.knownInviteGroups;
  List<Map<String, String?>> get allKnownGroups => _groupManager.allKnownGroups;

  Future<bool> get hasSavedGroup => _groupManager.hasSavedGroup;

  Future<Map<String, String?>?> getSavedConnectionDetails() =>
      _groupManager.getSavedConnectionDetails(AppConfig.livekitUrl);

  String getFriendlyName(String? roomName) =>
      _groupManager.getFriendlyName(roomName);

  Future<void> forgetGroup(String roomName) async {
    await _connectionManager.disconnectRoom(roomName);
    await _groupManager.forgetGroup(roomName);
  }

  bool isGroupConnected(String roomName) =>
      _connectionManager.isConnected(roomName);

  void setActiveRoom(String roomName) =>
      _connectionManager.setActiveRoom(roomName);

  int getRemoteParticipantCount(String roomName) =>
      _connectionManager.getRemoteParticipants(roomName).length;

  Future<int> getRoomStorageUsage(String roomName) async {
    return 0; // Placeholder
  }

  Future<Map<String, int>> getGroupStorageUsage() async {
    return {};
  }

  Future<SecretKey> getVaultKey(
    String roomName, {
    bool allowGenerateIfMissing = false,
  }) => _keyManager.getVaultKey(
    roomName,
    allowGenerateIfMissing: allowGenerateIfMissing,
  );
}
