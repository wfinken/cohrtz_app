import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import '../sync_service.dart';
import '../../runtime/crdt_service.dart';
import '../../runtime/hybrid_time_service.dart';

/// Orchestrates the leave-group flow.
///
/// Intended responsibilities:
/// - Remove local profile from the group
/// - Forget group and disconnect
/// - Advance active room selection
class LeaveGroupProcess {
  final SyncService _syncService;
  final CrdtService _crdtService;
  final HybridTimeService _hybridTimeService;

  LeaveGroupProcess({
    required SyncService syncService,
    required CrdtService crdtService,
    required HybridTimeService hybridTimeService,
  }) : _syncService = syncService,
       _crdtService = crdtService,
       _hybridTimeService = hybridTimeService;

  Future<void> execute(String roomName, {String? localUserId}) async {
    if (roomName.isEmpty) return;

    if (localUserId != null && localUserId.isNotEmpty) {
      final repo = DashboardRepository(
        _crdtService,
        roomName,
        _hybridTimeService,
      );
      await repo.deleteUserProfile(localUserId);
    }

    // Cleanup local database
    await _crdtService.deleteDatabase(roomName);

    await _syncService.forgetGroup(roomName);

    final remainingGroups = _syncService.knownGroups;
    if (remainingGroups.isNotEmpty) {
      final nextGroup = remainingGroups.first;
      final nextRoomName = nextGroup['roomName'] ?? '';
      _syncService.setActiveRoom(nextRoomName);
    } else {
      _syncService.setActiveRoom('');
    }
  }
}
