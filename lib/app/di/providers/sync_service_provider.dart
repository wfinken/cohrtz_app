import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/sync/orchestration/sync_service.dart';
import 'package:cohortz/slices/sync/contracts/sync_service_contract.dart';
import 'connection_manager_provider.dart';
import 'group_manager_provider.dart';
import 'key_manager_provider.dart';
import 'invite_handler_provider.dart';
import 'network_recovery_process_provider.dart';

class SyncServiceNotifier extends Notifier<SyncService> {
  late SyncService _service;

  @override
  SyncService build() {
    _service = SyncService(
      connectionManager: ref.watch(connectionManagerProvider),
      groupManager: ref.watch(groupManagerProvider),
      keyManager: ref.watch(keyManagerProvider),
      inviteHandler: ref.watch(inviteHandlerProvider),
      networkRecoveryProcess: ref.watch(networkRecoveryProcessProvider),
    );

    void listener() {
      state = _service;
    }

    _service.addListener(listener);

    ref.onDispose(() {
      _service.removeListener(listener);
      _service.dispose();
    });

    return _service;
  }

  @override
  bool updateShouldNotify(SyncService previous, SyncService next) {
    return true;
  }
}

final syncServiceProvider = NotifierProvider<SyncServiceNotifier, SyncService>(
  SyncServiceNotifier.new,
);

final iSyncServiceProvider = Provider<ISyncService>((ref) {
  return ref.watch(syncServiceProvider);
});
