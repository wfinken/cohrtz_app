import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/sync/orchestration/packet_handler.dart';
import 'security_provider.dart';
import 'encryption_provider.dart';
import 'packet_store_provider.dart';
import 'crdt_provider.dart';
import 'group_manager_provider.dart';
import 'handshake_handler_provider.dart';
import 'invite_handler_provider.dart';
import 'sync_protocol_provider.dart';
import 'treekem_handler_provider.dart';
import 'key_manager_provider.dart';
import 'node_id_provider.dart';
import 'data_broadcaster_provider.dart';
import 'connection_manager_provider.dart';
import 'identity_provider.dart';
import 'hybrid_time_provider.dart';

final packetHandlerProvider = Provider<PacketHandler>((ref) {
  return PacketHandler(
    hybridTimeService: ref.watch(hybridTimeServiceProvider),
    securityService: ref.watch(securityServiceProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    packetStore: ref.watch(packetStoreProvider),
    crdtService: ref.watch(crdtServiceProvider),
    groupManager: ref.watch(groupManagerProvider),
    handshakeHandler: ref.watch(handshakeHandlerProvider),
    inviteHandler: ref.watch(inviteHandlerProvider),
    syncProtocol: ref.watch(syncProtocolProvider),
    treekemHandler: ref.watch(treekemHandlerProvider),
    keyManager: ref.watch(keyManagerProvider),
    getLocalParticipantId: () => ref.read(nodeIdProvider),
    broadcastConsistencyCheck: (room) =>
        ref.read(syncProtocolProvider).broadcastConsistencyCheck(room),
    sendSecurePacket: (room, target, packet) => ref
        .read(dataBroadcasterProvider)
        .sendSecurePacket(room, target, packet),
    onGroupKeyShared: (room, target) =>
        ref.read(keyManagerProvider).shareGroupKeyIfHeld(room, target),
    onGroupKeyUpdated: (room, key) {
      ref.read(keyManagerProvider).setGroupKey(room, key);
      final group = ref.read(groupManagerProvider).findGroup(room);
      final isInviteRoom = group['isInviteRoom'] == 'true';
      if (!isInviteRoom &&
          ref.read(connectionManagerProvider).isConnected(room)) {
        ref.read(syncProtocolProvider).requestSync(room);
      }
    },
    onPeerHandshake: (room, peerId) {
      ref.read(dataBroadcasterProvider).retryPendingUnicast(room, peerId);
    },
    broadcast: (room, packet) =>
        ref.read(dataBroadcasterProvider).broadcast(room, packet),
    retryBroadcast: (room) =>
        ref.read(dataBroadcasterProvider).retryBufferedPackets(room),
    getLocalUserProfileJson: () {
      final profile = ref.read(identityServiceProvider).profile;
      return profile?.toJson();
    },
  );
});
