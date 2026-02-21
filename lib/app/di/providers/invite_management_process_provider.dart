import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/slices/members/orchestration/processes/invite_management_process.dart';
import 'sync_service_provider.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
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
