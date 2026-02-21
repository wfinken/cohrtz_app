import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/vault/state/packet_store.dart';

final packetStoreProvider = Provider<PacketStore>((ref) {
  return PacketStore();
});
