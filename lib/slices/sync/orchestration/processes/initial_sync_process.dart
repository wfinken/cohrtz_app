import 'dart:async';

import '../../runtime/connection_manager.dart';
import '../../runtime/group_manager.dart';
import '../../runtime/data_broadcaster.dart';
import '../handshake_handler.dart';
import '../sync_protocol.dart';
import 'sync_process.dart';

/// Orchestrates the initial sync after joining a data room.
///
/// Intended responsibilities:
/// - Ensure handshake/keys
/// - Trigger SYNC_REQ
/// - Retry pending packets
class InitialSyncProcess implements SyncProcess {
  final ConnectionManager _connectionManager;
  final GroupManager _groupManager;
  final HandshakeHandler _handshakeHandler;
  final SyncProtocol _syncProtocol;
  final DataBroadcaster _dataBroadcaster;

  /// Room to run the initial sync against.
  final String _roomName;

  InitialSyncProcess({
    required ConnectionManager connectionManager,
    required GroupManager groupManager,
    required HandshakeHandler handshakeHandler,
    required SyncProtocol syncProtocol,
    required DataBroadcaster dataBroadcaster,
    required String roomName,
  }) : _connectionManager = connectionManager,
       _groupManager = groupManager,
       _handshakeHandler = handshakeHandler,
       _syncProtocol = syncProtocol,
       _dataBroadcaster = dataBroadcaster,
       _roomName = roomName;

  @override
  Future<void> execute() async {
    if (!_connectionManager.isConnected(_roomName)) {
      return;
    }

    final group = _groupManager.findGroup(_roomName);
    final isInviteRoom = group['isInviteRoom'] == 'true';

    // Always advertise local keys, but avoid repeatedly requesting keys if
    // everyone already has an encryption key.
    await _handshakeHandler.broadcastHandshake(_roomName);
    await _requestHandshakeIfMissingKeys();

    if (isInviteRoom) {
      await _dataBroadcaster.retryBufferedPackets(_roomName);
      return;
    }

    await _connectionManager.ensureInviteRoomConnectedForDataRoom(_roomName);
    await _syncProtocol.requestSync(_roomName);

    await _dataBroadcaster.retryBufferedPackets(_roomName);

    // Kick off a short heartbeat window to pull any missed data after reconnect.
    unawaited(_runSyncHeartbeat());
  }

  Future<void> _runSyncHeartbeat() async {
    const attempts = 4;
    const interval = Duration(seconds: 2);

    for (var i = 0; i < attempts; i++) {
      if (!_connectionManager.isConnected(_roomName)) {
        return;
      }

      final remotes = _connectionManager.getRemoteParticipants(_roomName).keys;
      if (remotes.isNotEmpty) {
        await _requestHandshakeIfMissingKeys();
        await _dataBroadcaster.retryPendingUnicast(_roomName);
        await _syncProtocol.requestSync(_roomName);
      }

      await Future.delayed(interval);
    }
  }

  Future<void> _requestHandshakeIfMissingKeys() async {
    final remoteIdentities = _connectionManager
        .getRemoteParticipants(_roomName)
        .values
        .map((participant) => participant.identity)
        .where((identity) => identity.isNotEmpty)
        .toSet();

    if (remoteIdentities.isEmpty) return;

    final missingKeys = remoteIdentities.any(
      (identity) =>
          _handshakeHandler.getEncryptionKey(_roomName, identity) == null,
    );
    if (!missingKeys) return;

    await _handshakeHandler.requestHandshake(_roomName);
  }
}
