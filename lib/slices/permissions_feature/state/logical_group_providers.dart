import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cohortz/app/di/app_providers.dart';
import 'package:cohortz/slices/dashboard_shell/state/dashboard_repository.dart';
import 'package:cohortz/slices/permissions_core/acl_group_ids.dart';
import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_core/permission_providers.dart';
import 'package:cohortz/slices/permissions_core/permission_utils.dart';
import 'package:cohortz/slices/permissions_feature/models/logical_group_model.dart';
import 'package:cohortz/slices/permissions_feature/state/logical_group_repository.dart';
import 'package:cohortz/slices/permissions_feature/state/member_providers.dart';

final logicalGroupRepositoryProvider = Provider<LogicalGroupRepository>((ref) {
  final currentRoomName = ref.watch(
    syncServiceProvider.select((s) => s.currentRoomName),
  );
  return LogicalGroupRepository(ref.read(crdtServiceProvider), currentRoomName);
});

final persistedLogicalGroupsProvider = StreamProvider<List<LogicalGroup>>((
  ref,
) {
  final repo = ref.watch(logicalGroupRepositoryProvider);
  return repo.watchLogicalGroups();
});

final logicalGroupsProvider = Provider<List<LogicalGroup>>((ref) {
  final persisted = ref.watch(persistedLogicalGroupsProvider).value ?? const [];
  final members = ref.watch(membersProvider).value ?? const [];
  final profiles = ref.watch(userProfilesProvider).value ?? const [];

  final memberIds = <String>{
    for (final member in members) member.id,
    for (final profile in profiles) profile.id,
  };

  final everyone = LogicalGroup(
    id: AclGroupIds.everyone,
    name: 'Everyone',
    memberIds: memberIds.toList()..sort(),
    isSystem: true,
  );

  return [
    everyone,
    ...persisted.where((group) => group.id != AclGroupIds.everyone),
  ];
});

final myLogicalGroupIdsProvider = Provider<Set<String>>((ref) {
  final userId = ref.watch(syncServiceProvider.select((s) => s.identity)) ?? '';
  final groups = ref.watch(logicalGroupsProvider);
  final ids = <String>{AclGroupIds.everyone};

  if (userId.isEmpty) return ids;

  for (final group in groups) {
    if (group.memberIds.contains(userId)) {
      ids.add(group.id);
    }
  }
  return ids;
});

final canManageLogicalGroupsProvider = Provider<bool>((ref) {
  if (ref.watch(currentUserIsOwnerProvider)) {
    return true;
  }

  final permissions = ref.watch(currentUserPermissionsProvider).value;
  if (permissions == null) return false;

  if (PermissionUtils.has(permissions, PermissionFlags.administrator)) {
    return true;
  }

  return PermissionUtils.has(permissions, PermissionFlags.manageRoles) &&
      PermissionUtils.has(permissions, PermissionFlags.manageMembers);
});
