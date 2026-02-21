import 'package:dart_mappable/dart_mappable.dart';

part 'system_model.mapper.dart';

@MappableEnum()
enum GroupType {
  family,
  team,
  guild,
  apartment;

  String get displayName {
    switch (this) {
      case GroupType.family:
        return 'Family';
      case GroupType.team:
        return 'Team';
      case GroupType.guild:
        return 'Guild';
      case GroupType.apartment:
        return 'Apartment';
    }
  }

  String get calendarTitle {
    switch (this) {
      case GroupType.family:
        return 'CALENDAR';
      case GroupType.team:
        return 'SCHEDULE';
      case GroupType.guild:
        return 'EVENTS';
      case GroupType.apartment:
        return 'RESERVATIONS';
    }
  }

  String get tasksTitle {
    switch (this) {
      case GroupType.family:
        return 'CHORES';
      case GroupType.team:
        return 'TASKS';
      case GroupType.guild:
        return 'QUESTS';
      case GroupType.apartment:
        return 'MAINTENANCE';
    }
  }

  String get vaultTitle {
    switch (this) {
      case GroupType.family:
        return 'VAULT';
      case GroupType.team:
        return 'VAULT';
      case GroupType.guild:
        return 'TREASURY';
      case GroupType.apartment:
        return 'INFO';
    }
  }

  String get taskSingular {
    switch (this) {
      case GroupType.family:
        return 'Chore';
      case GroupType.team:
        return 'Task';
      case GroupType.guild:
        return 'Quest';
      case GroupType.apartment:
        return 'Issue';
    }
  }

  String get calendarSingular {
    switch (this) {
      case GroupType.family:
        return 'Event';
      case GroupType.team:
        return 'Event';
      case GroupType.guild:
        return 'Event';
      case GroupType.apartment:
        return 'Reservation';
    }
  }

  String get vaultSingular {
    return 'Item';
  }

  String get chatTitle {
    switch (this) {
      case GroupType.family:
        return 'FAMILY CHAT';
      case GroupType.team:
        return 'TEAM CHAT';
      case GroupType.guild:
        return 'TAVERN';
      case GroupType.apartment:
        return 'COMMONS';
    }
  }
}

@MappableClass()
class GroupInvite with GroupInviteMappable {
  final String code;
  final bool isSingleUse;
  final DateTime? expiresAt;
  final String roleId;

  GroupInvite({
    required this.code,
    this.isSingleUse = true,
    this.expiresAt,
    this.roleId = '',
  });

  bool get isValid {
    if (expiresAt != null && expiresAt!.isBefore(DateTime.now())) {
      return false;
    }
    return true;
  }
}

@MappableClass()
class GroupSettings with GroupSettingsMappable {
  final String id;
  final String name;
  final DateTime createdAt;
  final int logicalTime;
  final GroupType groupType;
  final String dataRoomName;
  final String ownerId;
  final List<GroupInvite> invites;
  final Map<String, GroupNotificationSettings> notificationSettingsByUser;

  GroupSettings({
    required this.id,
    required this.name,
    required this.createdAt,
    this.logicalTime = 0,
    this.groupType = GroupType.family,
    required this.dataRoomName,
    this.ownerId = '',
    this.invites = const [],
    this.notificationSettingsByUser = const {},
  });

  GroupNotificationSettings settingsForUser(String userId) {
    if (userId.isNotEmpty) {
      final userSettings = notificationSettingsByUser[userId];
      if (userSettings != null) return userSettings;
    }
    final fallback = notificationSettingsByUser['default'];
    return fallback ?? const GroupNotificationSettings();
  }
}

@MappableClass()
class GroupNotificationSettings with GroupNotificationSettingsMappable {
  final bool newTasks;
  final bool completedTasks;
  final bool calendarEvents;
  final bool vaultItems;
  final bool chatMessages;
  final bool newPolls;
  final bool closedPolls;
  final bool pollVotes;
  final bool memberJoined;
  final bool memberLeft;
  final bool allNotifications;

  const GroupNotificationSettings({
    this.newTasks = true,
    this.completedTasks = true,
    this.calendarEvents = true,
    this.vaultItems = true,
    this.chatMessages = true,
    this.newPolls = true,
    this.closedPolls = true,
    this.pollVotes = true,
    this.memberJoined = true,
    this.memberLeft = true,
    this.allNotifications = true,
  });

  GroupNotificationSettings withAll(bool enabled) {
    return copyWith(
      newTasks: enabled,
      completedTasks: enabled,
      calendarEvents: enabled,
      vaultItems: enabled,
      chatMessages: enabled,
      newPolls: enabled,
      closedPolls: enabled,
      pollVotes: enabled,
      memberJoined: enabled,
      memberLeft: enabled,
      allNotifications: enabled,
    );
  }
}
