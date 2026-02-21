import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/sync/application/invite_handler.dart';
import 'crdt_provider.dart';
import 'node_id_provider.dart';
import 'data_broadcaster_provider.dart';
import 'connection_manager_provider.dart';

final inviteHandlerProvider = Provider<InviteHandler>((ref) {
  return InviteHandler(
    crdtService: ref.watch(crdtServiceProvider),
    getLocalParticipantId: () => ref.read(nodeIdProvider),
    broadcast: (room, packet) =>
        ref.read(dataBroadcasterProvider).broadcast(room, packet),
    getConnectedRoomNames: () {
      return ref.read(connectionManagerProvider).connectedRoomNames;
    },
  );
});
