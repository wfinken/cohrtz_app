import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/sync/orchestration/processes/group_connection_process.dart';
import 'package:cohortz/slices/sync/orchestration/group_connection_status.dart';

import 'sync_service_provider.dart';
import 'invite_join_process_provider.dart';
import 'identity_provider.dart';

final groupConnectionProcessProvider = Provider<GroupConnectionProcess>((ref) {
  final notifier = ref.read(groupConnectionStatusProvider.notifier);
  return GroupConnectionProcess(
    syncService: ref.read(syncServiceProvider),
    inviteJoinProcess: ref.read(inviteJoinProcessProvider),
    identityService: ref.read(identityServiceProvider),
    onProcessStart: notifier.startProcess,
    onStepUpdate: notifier.updateStep,
    onProcessFail: notifier.failProcess,
    onProcessComplete: notifier.completeProcess,
  );
});
