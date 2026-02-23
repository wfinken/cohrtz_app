class GroupDescriptor {
  final String roomName;
  final String dataRoomName;
  final String? identity;
  final String? token;
  final bool isHost;
  final String friendlyName;
  final String? avatarBase64;
  final String? description;
  final bool isInviteRoom;
  final DateTime? lastJoined;

  const GroupDescriptor({
    required this.roomName,
    required this.dataRoomName,
    required this.identity,
    required this.token,
    required this.isHost,
    required this.friendlyName,
    required this.avatarBase64,
    required this.description,
    required this.isInviteRoom,
    required this.lastJoined,
  });

  factory GroupDescriptor.fromMap(Map<String, String?> map) {
    final roomName = map['roomName'] ?? '';
    final dataRoomName = map['dataRoomName'] ?? roomName;
    final friendlyName = map['friendlyName'] ?? roomName;
    final isHost = map['isHost'] == 'true';
    final isInviteRoom = map['isInviteRoom'] == 'true';
    final lastJoinedRaw = map['lastJoined'];
    return GroupDescriptor(
      roomName: roomName,
      dataRoomName: dataRoomName,
      identity: map['identity'],
      token: map['token'],
      isHost: isHost,
      friendlyName: friendlyName,
      avatarBase64: map['avatarBase64'],
      description: map['description'],
      isInviteRoom: isInviteRoom,
      lastJoined: lastJoinedRaw == null
          ? null
          : DateTime.tryParse(lastJoinedRaw),
    );
  }

  Map<String, String?> toMap() {
    return {
      'roomName': roomName,
      'dataRoomName': dataRoomName,
      'identity': identity,
      'token': token,
      'isHost': isHost.toString(),
      'friendlyName': friendlyName,
      'avatarBase64': avatarBase64,
      'description': description,
      'isInviteRoom': isInviteRoom.toString(),
      'lastJoined': lastJoined?.toIso8601String(),
    };
  }
}

class KnownGroupsSnapshot {
  final List<GroupDescriptor> dataGroups;
  final List<GroupDescriptor> inviteGroups;

  const KnownGroupsSnapshot({
    required this.dataGroups,
    required this.inviteGroups,
  });

  List<GroupDescriptor> get allGroups => [...dataGroups, ...inviteGroups];
}
