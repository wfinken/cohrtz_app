import 'dart:async';

import 'package:cohortz/slices/sync/orchestration/packet_handler.dart';
import 'package:cohortz/slices/sync/runtime/treekem_handler.dart';
import 'sync_process.dart';

/// Orchestrates TreeKEM rekey/update operations.
///
/// Intended responsibilities:
/// - Handle WELCOME/UPDATE flows
/// - Propagate group key updates
class RekeyProcess implements SyncProcess {
  final StreamSubscription<(String, dynamic)> _subscription;

  RekeyProcess({
    required TreeKemHandler treeKemHandler,
    required PacketHandler packetHandler,
  }) : _subscription = treeKemHandler.keyUpdates.listen((event) {
         packetHandler.updateGroupKey(event.$1, event.$2);
       });

  @override
  Future<void> execute() async {
    // This process is event-driven. Construction wires the key update stream.
  }

  Future<void> dispose() async {
    await _subscription.cancel();
  }
}
