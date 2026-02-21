import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/sync/runtime/treekem_handler.dart';
import 'crdt_provider.dart';
import 'security_provider.dart';
import 'encryption_provider.dart';
import 'secure_storage_provider.dart';

final treekemHandlerProvider = Provider<TreeKemHandler>((ref) {
  final handler = TreeKemHandler(
    crdtService: ref.watch(crdtServiceProvider),
    securityService: ref.watch(securityServiceProvider),
    encryptionService: ref.watch(encryptionServiceProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
    onStateChanged: () {
      // Optional UI update
    },
  );
  ref.onDispose(handler.dispose);
  return handler;
});

final treeKemEpochProvider = StreamProvider.family<int, String>((
  ref,
  roomName,
) async* {
  final handler = ref.watch(treekemHandlerProvider);
  yield handler.getEpoch(roomName);
  await for (final event in handler.epochUpdates) {
    if (event.$1 == roomName) {
      yield event.$2;
    }
  }
});
