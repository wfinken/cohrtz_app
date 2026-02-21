import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/features/dashboard/presentation/widgets/group_selection_rail.dart';
import 'package:cohortz/features/dashboard/presentation/widgets/group_button.dart';
import 'package:cohortz/features/sync/application/sync_service.dart';
import 'package:cohortz/features/sync/application/processes/network_recovery_process.dart';
import 'package:cohortz/core/providers.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/mocks.dart';

class FakeSyncService extends SyncService {
  FakeSyncService()
    : super(
        connectionManager: FakeConnectionManager(),
        groupManager: FakeGroupManager(),
        keyManager: FakeKeyManager(),
        inviteHandler: FakeInviteHandler(),
        networkRecoveryProcess: NetworkRecoveryProcess(
          connectionManager: FakeConnectionManager(),
        ),
      );

  List<Map<String, String>> _mockKnownGroups = [];

  void setKnownGroups(List<Map<String, String>> groups) {
    _mockKnownGroups = groups;
  }

  @override
  List<Map<String, String>> get knownGroups => _mockKnownGroups;

  @override
  Future<List<Map<String, String>>> getKnownGroups() async => _mockKnownGroups;

  @override
  Future<void> connectAllKnownGroups() async {}

  @override
  String? get currentRoomName =>
      _mockKnownGroups.isNotEmpty ? _mockKnownGroups[0]['roomName'] : null;

  @override
  bool isGroupConnected(String roomName) => true;

  @override
  void setActiveRoom(String roomName) {
    // no-op
  }
}

class FakeSyncServiceNotifier extends SyncServiceNotifier {
  final FakeSyncService _fakeService;
  FakeSyncServiceNotifier(this._fakeService);

  @override
  SyncService build() => _fakeService;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('GroupSelectionRail displays known groups', (
    WidgetTester tester,
  ) async {
    final fakeSync = FakeSyncService();
    fakeSync.setKnownGroups([
      {'roomName': 'room-1', 'friendlyName': 'Group One'},
      {'roomName': 'room-2', 'friendlyName': 'Group Two'},
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncServiceProvider.overrideWith(
            () => FakeSyncServiceNotifier(fakeSync),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: GroupSelectionRail())),
      ),
    );
    // GroupSelectionRail connects on init, wait for async
    await tester.pump();

    expect(find.byType(GroupButton), findsNWidgets(2));
  });
}
