import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/sync/orchestration/processes/network_recovery_process.dart';
import 'connection_manager_provider.dart';

final networkRecoveryProcessProvider = Provider<NetworkRecoveryProcess>((ref) {
  return NetworkRecoveryProcess(
    connectionManager: ref.read(connectionManagerProvider),
  );
});
