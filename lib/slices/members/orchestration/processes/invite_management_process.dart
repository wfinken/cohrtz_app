import 'dart:math';

import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import '../../../sync/orchestration/sync_service.dart';
import '../../../sync/runtime/hybrid_time_service.dart';

/// Orchestrates invite generation and revocation for a group.
class InviteManagementProcess {
  final DashboardRepository _dashboardRepository;
  final SyncService _syncService;
  final HybridTimeService _hybridTimeService;

  InviteManagementProcess({
    required DashboardRepository dashboardRepository,
    required SyncService syncService,
    required HybridTimeService hybridTimeService,
  }) : _dashboardRepository = dashboardRepository,
       _syncService = syncService,
       _hybridTimeService = hybridTimeService;

  GroupSettings resolveSettings(GroupSettings? currentSettings) {
    if (currentSettings != null) return currentSettings;

    final roomName = _syncService.currentRoomName ?? '';
    return GroupSettings(
      id: 'group_settings',
      name: _syncService.getFriendlyName(roomName),
      createdAt: _hybridTimeService.getAdjustedTimeLocal(),
      logicalTime: _hybridTimeService.nextLogicalTime(),
      dataRoomName: roomName,
      ownerId: _syncService.identity ?? '',
    );
  }

  Future<GroupInvite> createInvite({
    required GroupSettings? currentSettings,
    required bool isSingleUse,
    required Duration expiry,
    String roleId = '',
  }) async {
    final settings = resolveSettings(currentSettings);
    final invite = _generateInvite(
      isSingleUse: isSingleUse,
      expiry: expiry,
      roleId: roleId,
    );

    final updated = settings.copyWith(invites: [...settings.invites, invite]);
    await _dashboardRepository.saveGroupSettings(updated);
    return invite;
  }

  Future<void> revokeInvite({
    required GroupSettings? currentSettings,
    required String code,
  }) async {
    final settings = resolveSettings(currentSettings);
    final updated = settings.copyWith(
      invites: settings.invites.where((i) => i.code != code).toList(),
    );
    await _dashboardRepository.saveGroupSettings(updated);
  }

  GroupInvite _generateInvite({
    required bool isSingleUse,
    required Duration expiry,
    String roleId = '',
  }) {
    const chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    final rnd = Random();
    final newCode = String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
    return GroupInvite(
      code: newCode,
      isSingleUse: isSingleUse,
      expiresAt: _hybridTimeService.getAdjustedTimeLocal().add(expiry),
      roleId: roleId,
    );
  }
}
