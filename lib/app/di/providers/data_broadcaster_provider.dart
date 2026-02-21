import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/sync/runtime/data_broadcaster.dart';
import 'security_provider.dart';
import 'encryption_provider.dart';
import 'connection_manager_provider.dart';
import 'key_manager_provider.dart';
import 'handshake_handler_provider.dart';
import 'hybrid_time_provider.dart';

final Provider<DataBroadcaster> dataBroadcasterProvider =
    Provider<DataBroadcaster>((ref) {
      return DataBroadcaster(
        securityService: ref.watch(securityServiceProvider),
        encryptionService: ref.watch(encryptionServiceProvider),
        hybridTimeService: ref.watch(hybridTimeServiceProvider),
        getConnectionManager: () => ref.read(connectionManagerProvider),
        getGroupKey: (room, {allowWait = true}) => ref
            .read(keyManagerProvider)
            .getGroupKey(room, allowWait: allowWait),
        getEncryptionKey: (roomName, id) =>
            ref.read(handshakeHandlerProvider).getEncryptionKey(roomName, id),
        getLocalParticipantIdForRoom: (roomName) => ref
            .read(connectionManagerProvider)
            .resolveLocalParticipantIdForRoom(roomName),
      );
    });
