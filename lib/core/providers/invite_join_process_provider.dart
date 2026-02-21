import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/sync/application/processes/invite_join_process.dart';
import '../../features/sync/application/group_connection_status.dart';

import 'sync_service_provider.dart';
import 'key_manager_provider.dart';
import 'identity_provider.dart';
import 'crdt_provider.dart';
import 'hybrid_time_provider.dart';

final inviteJoinProcessProvider = Provider<InviteJoinProcess>((ref) {
  final notifier = ref.read(groupConnectionStatusProvider.notifier);
  return InviteJoinProcess(
    syncService: ref.read(syncServiceProvider),
    keyManager: ref.read(keyManagerProvider),
    identityService: ref.read(identityServiceProvider),
    crdtService: ref.read(crdtServiceProvider),
    hybridTimeService: ref.read(hybridTimeServiceProvider),
    onProcessStart: notifier.startProcess,
    onStepUpdate: notifier.updateStep,
  );
});
