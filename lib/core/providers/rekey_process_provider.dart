import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/sync/application/processes/rekey_process.dart';
import 'treekem_handler_provider.dart';
import 'packet_handler_provider.dart';

final rekeyProcessProvider = Provider<RekeyProcess>((ref) {
  final process = RekeyProcess(
    treeKemHandler: ref.read(treekemHandlerProvider),
    packetHandler: ref.read(packetHandlerProvider),
  );
  ref.onDispose(process.dispose);
  return process;
});
