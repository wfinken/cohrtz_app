import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cohortz/core/permissions/permission_flags.dart';
import 'package:cohortz/core/providers.dart';
import 'package:cohortz/features/dashboard/data/dashboard_repository.dart';
import 'package:cohortz/features/permissions/data/member_providers.dart';
import 'package:cohortz/features/permissions/data/role_providers.dart';

final currentUserPermissionsProvider = FutureProvider<int>((ref) async {
  final roomName = ref.watch(
    syncServiceProvider.select((s) => s.currentRoomName),
  );
  final userId =
      ref.watch(syncServiceProvider.select((s) => s.identity)) ??
      ref.watch(identityServiceProvider).profile?.id ??
      '';

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
  final userId =
      ref.watch(syncServiceProvider.select((s) => s.identity)) ??
      ref.watch(identityServiceProvider).profile?.id ??
      '';
  if (settings == null || userId.isEmpty) return false;
  return settings.ownerId.isNotEmpty && settings.ownerId == userId;
});
