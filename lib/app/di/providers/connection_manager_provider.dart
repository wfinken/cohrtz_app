import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/src/generated/p2p_packet.pb.dart';

import 'package:cohortz/slices/sync/runtime/connection_manager.dart';
import 'package:cohortz/slices/sync/orchestration/processes/initial_sync_process.dart';

import 'crdt_provider.dart';
import 'security_provider.dart';
import 'secure_storage_provider.dart';
import 'group_manager_provider.dart';
import 'node_id_provider.dart';
import 'packet_handler_provider.dart';
import 'handshake_handler_provider.dart';
import 'data_broadcaster_provider.dart';
import 'treekem_handler_provider.dart';
import 'sync_protocol_provider.dart';
import 'key_manager_provider.dart';
import 'hybrid_time_provider.dart';

InitialSyncProcess _buildInitialSyncProcess(
  Ref ref,
  ConnectionManager connectionManager,
  String room,
) {
  return InitialSyncProcess(
    connectionManager: connectionManager,
    groupManager: ref.read(groupManagerProvider),
    handshakeHandler: ref.read(handshakeHandlerProvider),
    syncProtocol: ref.read(syncProtocolProvider),
    dataBroadcaster: ref.read(dataBroadcasterProvider),
    roomName: room,
  );
}

// Explicit types to prevent inference cycles
final Provider<ConnectionManager>
connectionManagerProvider = Provider<ConnectionManager>((ref) {
  final initialSyncInFlight = <String>{};
  final lastInitialSyncAt = <String, DateTime>{};
  late final ConnectionManager manager;

  manager = ConnectionManager(
    crdtService: ref.watch(crdtServiceProvider),
    securityService: ref.watch(securityServiceProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
    groupManager: ref.watch(groupManagerProvider),
    nodeId: ref.watch(nodeIdProvider),
    onDataReceived: (room, event) async {
      // Only access PacketHandler when data arrives
      await ref.read(packetHandlerProvider).onDataReceived(room, event.data);
    },
    onParticipantConnected: (room, event) async {
      // Handshake Trigger
      await ref.read(handshakeHandlerProvider).broadcastHandshake(room);
      // Flush any pending buffers now that a peer exists.
      await ref.read(dataBroadcasterProvider).retryBufferedPackets(room);

      final peerId = event.participant.identity;
      final localId = manager.resolveLocalParticipantIdForRoom(room);
      if (peerId.isNotEmpty && localId.isNotEmpty) {
        // Deterministic "initiator" for the pair: only one side pings.
        final shouldInitiate = localId.compareTo(peerId) < 0;
        if (shouldInitiate) {
          final time = ref.read(hybridTimeServiceProvider);
          final ping = time.buildSyncPing(
            peerId: peerId,
            localParticipantId: localId,
          );
          await ref.read(dataBroadcasterProvider).broadcast(room, ping);
        }
      }
    },
    onParticipantDisconnected: (room, event) {
      final peerId = event.participant.identity;
      if (peerId.isNotEmpty) {
        ref.read(hybridTimeServiceProvider).removePeer(peerId);
      }
    },
    onRoomConnectionStateChanged: (manager, room) async {
      final isConnected = manager.isConnected(room);
      if (isConnected) {
        if (initialSyncInFlight.contains(room)) return;

        final now = DateTime.now();
        final last = lastInitialSyncAt[room];
        if (last != null && now.difference(last) < const Duration(seconds: 8)) {
          return;
        }

        initialSyncInFlight.add(room);
        try {
          // Avoid triggering initial sync during brief connected/disconnected
          // state flaps while the peer connection is still settling.
          await Future.delayed(const Duration(milliseconds: 800));
          if (!manager.isConnected(room)) return;

          await _buildInitialSyncProcess(ref, manager, room).execute();
          lastInitialSyncAt[room] = DateTime.now();
        } finally {
          initialSyncInFlight.remove(room);
        }
      }
    },
    onInitializeSync: (room, isHost) async {
      await ref
          .read(treekemHandlerProvider)
          .initializeForRoom(room, isHost: isHost);
    },
    onCleanupSync: (room) {
      ref.read(keyManagerProvider).clearGroupKey(room, clearStored: false);
      ref.read(handshakeHandlerProvider).clearRoom(room);
    },
    onLocalDataChanged: (room, data) async {
      // Guard: Don't broadcast if we don't have the key yet (prevents "GSK missing" errors)
      // The data is already in the local CRDT, so it will be synced when we get the key
      // and triggering a Sync/Consistency check.
      // UPDATE: We now rely on DataBroadcaster to buffer these packets if the key is missing.
      // So we proceed to attempt broadcast.
      final packet = P2PPacket()
        ..type = P2PPacket_PacketType.DATA_CHUNK
        ..requestId = const Uuid().v4()
        ..senderId = manager.resolveLocalParticipantIdForRoom(room)
        ..payload = data;
      await ref.read(dataBroadcasterProvider).broadcast(room, packet);
    },
  );
  ref.onDispose(manager.dispose);
  return manager;
});
