import 'dart:async';

import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/sync/runtime/connection_manager.dart';
import 'package:cohortz/slices/sync/runtime/crdt_service.dart';
import 'package:cohortz/slices/sync/runtime/group_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mocks.dart';

class _SavedGroupCall {
  final String roomName;
  final String dataRoomName;
  final String identity;
  final String? friendlyName;
  final String? avatarBase64;
  final String? description;
  final bool isInviteRoom;
  final bool isHost;

  _SavedGroupCall({
    required this.roomName,
    required this.dataRoomName,
    required this.identity,
    required this.friendlyName,
    required this.avatarBase64,
    required this.description,
    required this.isInviteRoom,
    required this.isHost,
  });
}

class _RecordingGroupManager extends GroupManager {
  final Map<String, Map<String, String?>> _groupsByRoom;
  final List<_SavedGroupCall> saveCalls = [];

  _RecordingGroupManager({required Map<String, Map<String, String?>> groups})
    : _groupsByRoom = groups,
      super(secureStorage: FakeSecureStorageService());

  @override
  Map<String, String?> findGroup(String roomName) {
    return _groupsByRoom[roomName] ?? {};
  }

  @override
  Future<void> saveKnownGroup(
    String roomName,
    String dataRoomName,
    String identity, {
    String? friendlyName,
    String? avatarBase64,
    String? description,
    bool isInviteRoom = false,
    bool isHost = false,
    String? token,
  }) async {
    saveCalls.add(
      _SavedGroupCall(
        roomName: roomName,
        dataRoomName: dataRoomName,
        identity: identity,
        friendlyName: friendlyName,
        avatarBase64: avatarBase64,
        description: description,
        isInviteRoom: isInviteRoom,
        isHost: isHost,
      ),
    );
  }
}

class _WatchableCrdtService extends CrdtService {
  final StreamController<List<Map<String, Object?>>> groupSettingsController =
      StreamController<List<Map<String, Object?>>>.broadcast();

  List<Map<String, Object?>> groupSettingsRows;

  _WatchableCrdtService({required this.groupSettingsRows});

  @override
  Stream<List<Map<String, Object?>>> watch(
    String roomName,
    String sql, [
    List<Object?>? args,
  ]) {
    if (sql.contains('FROM group_settings')) {
      return groupSettingsController.stream;
    }
    return Stream.value([]);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String roomName,
    String sql, [
    List<Object?>? args,
  ]) async {
    if (sql.contains('FROM group_settings')) {
      return groupSettingsRows;
    }
    return [];
  }
}

void main() {
  test(
    'Group settings watch refreshes known-group metadata after remote update',
    () async {
      const roomName = 'room-42';
      final settings = GroupSettings(
        id: 'group_settings',
        name: 'Updated Group',
        description: 'New description',
        avatarBase64: 'remote-avatar-base64',
        createdAt: DateTime.utc(2026, 1, 1),
        dataRoomName: roomName,
      );

      final crdt = _WatchableCrdtService(
        groupSettingsRows: [
          {'id': 'group_settings', 'value': settings.toJson()},
        ],
      );
      final groupManager = _RecordingGroupManager(
        groups: {
          roomName: {
            'roomName': roomName,
            'dataRoomName': roomName,
            'identity': 'user:local',
            'friendlyName': 'Old Name',
            'avatarBase64': '',
            'description': '',
            'isInviteRoom': 'false',
            'isHost': 'false',
          },
        },
      );

      final manager = ConnectionManager(
        crdtService: crdt,
        securityService: FakeSecurityService(),
        secureStorage: FakeSecureStorageService(),
        groupManager: groupManager,
        nodeId: 'node-id',
        onDataReceived: (_, __) {},
        onParticipantConnected: (_, __) {},
        onParticipantDisconnected: (_, __) {},
        onRoomConnectionStateChanged: (_, __) {},
        onLocalDataChanged: (_, __) {},
        onInitializeSync: (_, __) async {},
        onCleanupSync: (_) {},
      );

      await manager.startGroupSettingsWatchForTesting(roomName);
      crdt.groupSettingsController.add(const []);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(groupManager.saveCalls.length, 1);
      final call = groupManager.saveCalls.single;
      expect(call.roomName, roomName);
      expect(call.friendlyName, 'Updated Group');
      expect(call.avatarBase64, 'remote-avatar-base64');
      expect(call.description, 'New description');

      manager.dispose();
      await crdt.groupSettingsController.close();
    },
  );
}
