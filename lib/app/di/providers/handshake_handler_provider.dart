import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/sync/orchestration/handshake_handler.dart';
import 'security_provider.dart';
import 'node_id_provider.dart';
import 'data_broadcaster_provider.dart';

final Provider<HandshakeHandler> handshakeHandlerProvider =
    Provider<HandshakeHandler>((ref) {
      return HandshakeHandler(
        securityService: ref.watch(securityServiceProvider),
        getLocalParticipantId: () => ref.read(nodeIdProvider),
        broadcast: (room, packet) =>
            ref.read(dataBroadcasterProvider).broadcast(room, packet),
      );
    });
