import 'package:cohortz/slices/permissions_core/permission_flags.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';

const _ownerRoleName = 'owner';

bool isOwnerRole(Role role) {
  return role.name.trim().toLowerCase() == _ownerRoleName;
}

List<Role> sortRolesByPermissionLevel(Iterable<Role> roles) {
  final sorted = [...roles];
  sorted.sort(compareRolesByPermissionLevel);
  return sorted;
}

int compareRolesByPermissionLevel(Role a, Role b) {
  final aIsOwner = isOwnerRole(a);
  final bIsOwner = isOwnerRole(b);
  if (aIsOwner != bIsOwner) {
    return aIsOwner ? -1 : 1;
  }

  final aWeight = rolePermissionWeight(a);
  final bWeight = rolePermissionWeight(b);
  final weightComparison = bWeight.compareTo(aWeight);
  if (weightComparison != 0) {
    return weightComparison;
  }

  final aBitCount = roleEnabledPermissionCount(a);
  final bBitCount = roleEnabledPermissionCount(b);
  final bitCountComparison = bBitCount.compareTo(aBitCount);
  if (bitCountComparison != 0) {
    return bitCountComparison;
  }

  final positionComparison = b.position.compareTo(a.position);
  if (positionComparison != 0) {
    return positionComparison;
  }

  final nameComparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  if (nameComparison != 0) {
    return nameComparison;
  }

  return a.id.compareTo(b.id);
}

int rolePermissionWeight(Role role) {
  return permissionWeight(role.permissions);
}

int roleEnabledPermissionCount(Role role) {
  final normalized = PermissionFlags.normalize(role.permissions);
  if (normalized == PermissionFlags.all) {
    return 1 << 20;
  }
  return _countBits(normalized);
}

int permissionWeight(int permissions) {
  final normalized = PermissionFlags.normalize(permissions);
  if (normalized == PermissionFlags.all ||
      (normalized & PermissionFlags.administrator) != 0) {
    return 1 << 30;
  }

  var score = 0;
  score += _scoreFlags(normalized, _criticalManagementFlags, 1_000_000);
  score += _scoreFlags(normalized, _widgetManagementFlags, 100_000);
  score += _scoreFlags(normalized, _editFlags, 10_000);
  score += _scoreFlags(normalized, _createOrInteractFlags, 1_000);
  score += _scoreFlags(normalized, _baseFlags, 100);
  return score;
}

const _criticalManagementFlags = <int>[
  PermissionFlags.manageRoles,
  PermissionFlags.manageMembers,
  PermissionFlags.manageInvites,
  PermissionFlags.manageGroup,
];

const _widgetManagementFlags = <int>[
  PermissionFlags.manageCalendar,
  PermissionFlags.manageVault,
  PermissionFlags.manageTasks,
  PermissionFlags.manageNotes,
  PermissionFlags.manageChat,
  PermissionFlags.managePolls,
];

const _editFlags = <int>[
  PermissionFlags.editCalendar,
  PermissionFlags.editTasks,
  PermissionFlags.editPolls,
  PermissionFlags.editVault,
  PermissionFlags.editNotes,
  PermissionFlags.editChat,
  PermissionFlags.editMembers,
];

const _createOrInteractFlags = <int>[
  PermissionFlags.createCalendar,
  PermissionFlags.createTasks,
  PermissionFlags.createPolls,
  PermissionFlags.createVault,
  PermissionFlags.createNotes,
  PermissionFlags.interactCalendar,
  PermissionFlags.interactTasks,
  PermissionFlags.interactPolls,
  PermissionFlags.interactVault,
];

const _baseFlags = <int>[
  PermissionFlags.viewCalendar,
  PermissionFlags.viewTasks,
  PermissionFlags.viewPolls,
  PermissionFlags.viewVault,
  PermissionFlags.viewNotes,
  PermissionFlags.viewChat,
  PermissionFlags.viewMembers,
  PermissionFlags.mentionEveryone,
  PermissionFlags.createChatRooms,
  PermissionFlags.editChatRooms,
  PermissionFlags.deleteChatRooms,
  PermissionFlags.startPrivateChats,
  PermissionFlags.leavePrivateChats,
];

int _scoreFlags(int permissions, List<int> flags, int weight) {
  var score = 0;
  for (final flag in flags) {
    if ((permissions & flag) != 0) {
      score += weight;
    }
  }
  return score;
}

int _countBits(int value) {
  if (value < 0) return 1 << 20;
  var count = 0;
  var current = value;
  while (current != 0) {
    count += current & 1;
    current >>= 1;
  }
  return count;
}
