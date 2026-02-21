import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/sync/application/processes/leave_group_process.dart';
import 'sync_service_provider.dart';
import 'crdt_provider.dart';
import 'hybrid_time_provider.dart';

final leaveGroupProcessProvider = Provider<LeaveGroupProcess>((ref) {
  return LeaveGroupProcess(
    syncService: ref.read(syncServiceProvider),
    crdtService: ref.read(crdtServiceProvider),
    hybridTimeService: ref.read(hybridTimeServiceProvider),
  );
});
