import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/vault/data/packet_store.dart';

final packetStoreProvider = Provider<PacketStore>((ref) {
  return PacketStore();
});
