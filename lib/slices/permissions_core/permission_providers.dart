import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/app/di/app_providers.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/permissions_feature/state/member_providers.dart';
import 'package:cohortz/slices/permissions_feature/state/role_providers.dart';

final currentUserPermissionsProvider = FutureProvider<int>((ref) async {
  final syncService = ref.watch(syncServiceProvider);
  final roomName = syncService.currentRoomName;
  final userId = roomName == null
      ? ''
      : (syncService.getLocalParticipantIdForRoom(roomName) ??
            syncService.identity ??
            '');

  ref.watch(rolesProvider);
  ref.watch(membersProvider);
  ref.watch(groupSettingsProvider);

  if (roomName == null || roomName.isEmpty || userId.isEmpty) {
    return PermissionFlags.none;
  }

  final service = ref.watch(permissionServiceProvider);
  return service.calculatePermissions(roomName, userId);
});

final currentUserIsOwnerProvider = Provider<bool>((ref) {
  final settings = ref.watch(groupSettingsProvider).value;
  final syncService = ref.watch(syncServiceProvider);
  final roomName = syncService.currentRoomName;
  final userId = roomName == null
      ? ''
      : (syncService.getLocalParticipantIdForRoom(roomName) ??
            syncService.identity ??
            '');
  if (settings == null || userId.isEmpty) return false;
  return settings.ownerId.isNotEmpty && settings.ownerId == userId;
});
