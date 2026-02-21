import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/sync/orchestration/processes/invite_join_process.dart';
import 'package:cohortz/slices/sync/orchestration/group_connection_status.dart';

import 'sync_service_provider.dart';
import 'key_manager_provider.dart';
import 'group_identity_provider.dart';
import 'crdt_provider.dart';
import 'hybrid_time_provider.dart';

final inviteJoinProcessProvider = Provider<InviteJoinProcess>((ref) {
  final notifier = ref.read(groupConnectionStatusProvider.notifier);
  return InviteJoinProcess(
    syncService: ref.read(syncServiceProvider),
    keyManager: ref.read(keyManagerProvider),
    groupIdentityService: ref.read(groupIdentityServiceProvider),
    crdtService: ref.read(crdtServiceProvider),
    hybridTimeService: ref.read(hybridTimeServiceProvider),
    onProcessStart: notifier.startProcess,
    onStepUpdate: notifier.updateStep,
  );
});
