import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/sync/orchestration/handshake_handler.dart';
import 'security_provider.dart';
import 'data_broadcaster_provider.dart';
import 'connection_manager_provider.dart';

final Provider<HandshakeHandler> handshakeHandlerProvider =
    Provider<HandshakeHandler>((ref) {
      return HandshakeHandler(
        securityService: ref.watch(securityServiceProvider),
        getLocalParticipantIdForRoom: (roomName) => ref
            .read(connectionManagerProvider)
            .resolveLocalParticipantIdForRoom(roomName),
        broadcast: (room, packet) =>
            ref.read(dataBroadcasterProvider).broadcast(room, packet),
      );
    });
