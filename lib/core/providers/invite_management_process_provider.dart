import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/dashboard/application/processes/invite_management_process.dart';
import 'sync_service_provider.dart';
import '../../features/dashboard/data/dashboard_repository.dart';
import 'hybrid_time_provider.dart';

final inviteManagementProcessProvider = Provider<InviteManagementProcess>((
  ref,
) {
  return InviteManagementProcess(
    dashboardRepository: ref.read(dashboardRepositoryProvider),
    syncService: ref.read(syncServiceProvider),
    hybridTimeService: ref.read(hybridTimeServiceProvider),
  );
});
