import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/sync/orchestration/invite_handler.dart';
import 'crdt_provider.dart';
import 'data_broadcaster_provider.dart';
import 'connection_manager_provider.dart';

final inviteHandlerProvider = Provider<InviteHandler>((ref) {
  return InviteHandler(
    crdtService: ref.watch(crdtServiceProvider),
    getLocalParticipantIdForRoom: (roomName) => ref
        .read(connectionManagerProvider)
        .resolveLocalParticipantIdForRoom(roomName),
    broadcast: (room, packet) =>
        ref.read(dataBroadcasterProvider).broadcast(room, packet),
    getConnectedRoomNames: () {
      return ref.read(connectionManagerProvider).connectedRoomNames;
    },
  );
});
