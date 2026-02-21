import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/sync/orchestration/sync_protocol.dart';
import 'crdt_provider.dart';
import 'permission_provider.dart';
import 'data_broadcaster_provider.dart';
import 'key_manager_provider.dart';
import 'connection_manager_provider.dart';

final syncProtocolProvider = Provider<SyncProtocol>((ref) {
  return SyncProtocol(
    crdtService: ref.watch(crdtServiceProvider),
    permissionService: ref.watch(permissionServiceProvider),
    getLocalParticipantIdForRoom: (roomName) => ref
        .read(connectionManagerProvider)
        .resolveLocalParticipantIdForRoom(roomName),
    broadcast: (room, packet) =>
        ref.read(dataBroadcasterProvider).broadcast(room, packet),
    sendSecure: (room, target, packet) => ref
        .read(dataBroadcasterProvider)
        .sendSecurePacket(room, target, packet),
    getGroupKey: (room) => ref.read(keyManagerProvider).getGroupKey(room),
  );
});
