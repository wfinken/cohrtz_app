import 'acl_group_ids.dart';

List<String> normalizeVisibilityGroupIds(Iterable<String>? groupIds) {
  final normalized = <String>{};
  if (groupIds != null) {
    for (final rawId in groupIds) {
      final id = rawId.trim();
      if (id.isEmpty) continue;
      normalized.add(id);
    }
  }

  if (normalized.isEmpty) {
    return const [AclGroupIds.everyone];
  }

  if (normalized.contains(AclGroupIds.everyone)) {
    return const [AclGroupIds.everyone];
  }

  return normalized.toList(growable: false);
}

bool canViewByLogicalGroups({
  required Iterable<String>? itemGroupIds,
  required Set<String> viewerGroupIds,
  bool bypass = false,
}) {
  if (bypass) return true;

  final visibilityGroups = normalizeVisibilityGroupIds(itemGroupIds);
  if (visibilityGroups.contains(AclGroupIds.everyone)) return true;
  if (viewerGroupIds.contains(AclGroupIds.everyone)) return true;

  for (final id in visibilityGroups) {
    if (viewerGroupIds.contains(id)) {
      return true;
    }
  }
  return false;
}
