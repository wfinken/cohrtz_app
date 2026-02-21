import 'dart:convert';

import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/sync/runtime/connection_manager.dart';
import 'package:cohortz/slices/sync/runtime/crdt_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mocks.dart';

class _PutCall {
  final String roomName;
  final String key;
  final String value;
  final String tableName;

  _PutCall({
    required this.roomName,
    required this.key,
    required this.value,
    required this.tableName,
  });
}

class _RecordingCrdtService extends CrdtService {
  final List<Map<String, Object?>> groupSettingsRows;
  final List<_PutCall> puts = [];

  _RecordingCrdtService({required this.groupSettingsRows});

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

  @override
  Future<void> put(
    String roomName,
    String key,
    String value, {
    String tableName = 'cohrtz',
  }) async {
    puts.add(
      _PutCall(
        roomName: roomName,
        key: key,
        value: value,
        tableName: tableName,
      ),
    );
  }
}

void main() {
  test('Pruning expired invites writes valid group_settings JSON', () async {
    const roomName = 'data-room-123';
    final expired = DateTime.now().subtract(const Duration(days: 1));
    final valid = DateTime.now().add(const Duration(days: 1));

    final settings = GroupSettings(
      id: 'group_settings',
      name: 'My Group',
      createdAt: DateTime.utc(2026, 1, 1),
      dataRoomName: roomName,
      invites: [
        GroupInvite(code: 'EXPIRED', isSingleUse: true, expiresAt: expired),
        GroupInvite(code: 'VALID', isSingleUse: true, expiresAt: valid),
      ],
    );

    final crdt = _RecordingCrdtService(
      groupSettingsRows: [
        {'id': 'group_settings', 'value': jsonEncode(settings.toMap())},
      ],
    );

    final manager = ConnectionManager(
      crdtService: crdt,
      securityService: FakeSecurityService(),
      secureStorage: FakeSecureStorageService(),
      groupManager: FakeGroupManager(),
      nodeId: 'node-id',
      onDataReceived: (_, __) {},
      onParticipantConnected: (_, __) {},
      onParticipantDisconnected: (_, __) {},
      onRoomConnectionStateChanged: (_, __) {},
      onLocalDataChanged: (_, __) {},
      onInitializeSync: (_, __) async {},
      onCleanupSync: (_) {},
    );

    await manager.pruneExpiredInvitesForTesting(roomName);

    expect(crdt.puts.length, 1);
    expect(crdt.puts.single.roomName, roomName);
    expect(crdt.puts.single.key, 'group_settings');
    expect(crdt.puts.single.tableName, 'group_settings');

    expect(
      () => GroupSettingsMapper.fromJson(crdt.puts.single.value),
      returnsNormally,
    );
    final written = GroupSettingsMapper.fromJson(crdt.puts.single.value);
    expect(written.invites.map((i) => i.code), ['VALID']);
  });
}
