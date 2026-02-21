import 'package:cohortz/slices/sync/orchestration/processes/group_connection_process.dart';
import 'package:cohortz/slices/sync/orchestration/sync_service.dart';
import 'package:cohortz/app/di/providers/sync_service_provider.dart';
import 'package:cohortz/slices/sync/orchestration/processes/network_recovery_process.dart';

import '../../test/helpers/mocks.dart';

class TestSyncService extends SyncService {
  TestSyncService({
    List<Map<String, String?>> knownGroups = const [],
    String? activeRoomName,
    this.connected = false,
  }) : super(
         connectionManager: FakeConnectionManager(),
         groupManager: FakeGroupManager(),
         keyManager: FakeKeyManager(),
         inviteHandler: FakeInviteHandler(),
         networkRecoveryProcess: NetworkRecoveryProcess(
           connectionManager: FakeConnectionManager(),
         ),
       ) {
    setKnownGroups(knownGroups, activeRoomName: activeRoomName);
  }

  bool connected;
  List<Map<String, String?>> _knownGroups = <Map<String, String?>>[];
  String? _activeRoomName;

  void setKnownGroups(
    List<Map<String, String?>> groups, {
    String? activeRoomName,
  }) {
    _knownGroups = groups
        .map((group) => Map<String, String?>.from(group))
        .toList();
    _activeRoomName =
        activeRoomName ??
        (_knownGroups.isNotEmpty ? _knownGroups.first['roomName'] : null);
  }

  @override
  String? get identity => 'integration-test-user';

  @override
  bool get isConnected => connected && _activeRoomName != null;

  @override
  bool get isActiveRoomConnected => _activeRoomName != null;

  @override
  bool get isActiveRoomConnecting => false;

  @override
  String? get currentRoomName => _activeRoomName;

  @override
  List<Map<String, String?>> get knownGroups => _knownGroups;

  @override
  Future<List<Map<String, String?>>> getKnownGroups() async => _knownGroups;

  @override
  Future<void> connectAllKnownGroups() async {}

  @override
  bool isGroupConnected(String roomName) {
    return connected && _activeRoomName == roomName;
  }

  @override
  void setActiveRoom(String roomName) {
    connected = true;
    _activeRoomName = roomName;
    notifyListeners();
  }

  @override
  int getRemoteParticipantCount(String roomName) => 0;

  @override
  String getFriendlyName(String? roomName) {
    if (roomName == null || roomName.isEmpty) return 'Group';
    for (final group in _knownGroups) {
      if (group['roomName'] == roomName) {
        return group['friendlyName'] ?? roomName;
      }
    }
    return roomName;
  }
}

class TestSyncServiceNotifier extends SyncServiceNotifier {
  TestSyncServiceNotifier(this._service);

  final TestSyncService _service;

  @override
  SyncService build() {
    void listener() {
      state = _service;
    }

    _service.addListener(listener);
    ref.onDispose(() {
      _service.removeListener(listener);
      _service.dispose();
    });
    return _service;
  }

  @override
  bool updateShouldNotify(SyncService previous, SyncService next) => true;
}

class FakeGroupConnectionProcess implements GroupConnectionProcess {
  const FakeGroupConnectionProcess({this.autoJoinResult = false});

  final bool autoJoinResult;

  @override
  Future<void> connect(String roomName, {String inviteCode = ''}) async {}

  @override
  Future<bool> autoJoinSaved() async => autoJoinResult;
}
