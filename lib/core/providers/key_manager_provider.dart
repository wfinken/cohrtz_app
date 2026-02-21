import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/sync/infrastructure/key_manager.dart';
import 'encryption_provider.dart';
import 'secure_storage_provider.dart';
import 'treekem_handler_provider.dart';
import 'node_id_provider.dart';
import 'data_broadcaster_provider.dart';
import 'connection_manager_provider.dart';
import 'group_manager_provider.dart';

final Provider<KeyManager> keyManagerProvider = Provider<KeyManager>((ref) {
  return KeyManager(
    encryptionService: ref.watch(encryptionServiceProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
    treeKemHandler: ref.watch(treekemHandlerProvider),
    getLocalParticipantId: () => ref.read(nodeIdProvider),
    broadcast: (room, packet) =>
        ref.read(dataBroadcasterProvider).broadcast(room, packet),
    getRemoteParticipantIds: (room) {
      return ref
          .read(connectionManagerProvider)
          .getRemoteParticipants(room)
          .values
          .map((p) => p.identity)
          .where((id) => id.isNotEmpty);
    },
    sendSecure: (room, target, packet) => ref
        .read(dataBroadcasterProvider)
        .sendSecurePacket(room, target, packet),
    getRemoteParticipantCount: (room) {
      return ref
          .read(connectionManagerProvider)
          .getRemoteParticipants(room)
          .length;
    },
    isHost: (room) {
      final group = ref.read(groupManagerProvider).findGroup(room);
      return group['isHost'] == 'true';
    },
  );
});
