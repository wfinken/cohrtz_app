import 'dart:convert';

import 'package:cohortz/slices/dashboard_shell/models/system_model.dart';
import 'package:cohortz/slices/sync/orchestration/invite_handler.dart';
import 'package:cohortz/slices/sync/runtime/crdt_service.dart';
import 'package:cohortz/src/generated/p2p_packet.pb.dart';
import 'package:flutter_test/flutter_test.dart';

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
    if (sql.contains('FROM roles')) {
      return [];
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
  group('InviteHandler single-use consumption', () {
    test('Consumes token using the actual group_settings row id', () async {
      const inviteRoomName = 'My Group';
      const dataRoomName = 'data-room-123';
      const inviteCode = 'CODE123';

      final settings = GroupSettings(
        id: 'group_settings',
        name: inviteRoomName,
        createdAt: DateTime.utc(2026, 1, 1),
        dataRoomName: dataRoomName,
        invites: [
          GroupInvite(
            code: inviteCode,
            isSingleUse: true,
            expiresAt: DateTime.now().add(const Duration(days: 1)),
          ),
        ],
      );

      final crdt = _RecordingCrdtService(
        groupSettingsRows: [
          {
            // Simulate a legacy/migrated row key that does not match JSON `id`.
            'id': 'group_settings:legacy',
            'value': jsonEncode(settings.toMap()),
          },
        ],
      );

      final broadcastPackets = <P2PPacket>[];
      final handler = InviteHandler(
        crdtService: crdt,
        getLocalParticipantIdForRoom: (_) => 'host',
        broadcast: (room, packet) async {
          expect(room, inviteRoomName);
          broadcastPackets.add(packet);
        },
        getConnectedRoomNames: () => <String>{dataRoomName},
      );

      final packet = P2PPacket()
        ..type = P2PPacket_PacketType.INVITE_REQ
        ..requestId = 'req-1'
        ..senderId = 'joiner'
        ..payload = utf8.encode(inviteCode);

      await handler.handleInviteReq(inviteRoomName, packet);

      expect(crdt.puts.length, 1);
      expect(crdt.puts.single.roomName, dataRoomName);
      expect(crdt.puts.single.key, 'group_settings:legacy');
      expect(crdt.puts.single.tableName, 'group_settings');

      final written =
          jsonDecode(crdt.puts.single.value) as Map<String, dynamic>;
      final invites = (written['invites'] as List).cast<Map>();
      expect(invites.where((i) => i['code'] == inviteCode), isEmpty);

      expect(broadcastPackets.length, 1);
      expect(broadcastPackets.single.type, P2PPacket_PacketType.INVITE_ACK);
      expect(broadcastPackets.single.requestId, 'req-1');
      expect(utf8.decode(broadcastPackets.single.payload), dataRoomName);
    });

    test('Consumes token across duplicate group_settings rows', () async {
      const inviteRoomName = 'My Group';
      const dataRoomName = 'data-room-123';
      const inviteCode = 'CODE123';

      final settings = GroupSettings(
        id: 'group_settings',
        name: inviteRoomName,
        createdAt: DateTime.utc(2026, 1, 1),
        dataRoomName: dataRoomName,
        invites: [
          GroupInvite(
            code: inviteCode,
            isSingleUse: true,
            expiresAt: DateTime.now().add(const Duration(days: 1)),
          ),
        ],
      );

      final crdt = _RecordingCrdtService(
        groupSettingsRows: [
          {'id': 'group_settings', 'value': jsonEncode(settings.toMap())},
          {
            'id': 'group_settings:legacy',
            'value': jsonEncode(settings.toMap()),
          },
        ],
      );

      final handler = InviteHandler(
        crdtService: crdt,
        getLocalParticipantIdForRoom: (_) => 'host',
        broadcast: (room, packet) async {},
        getConnectedRoomNames: () => <String>{dataRoomName},
      );

      final packet = P2PPacket()
        ..type = P2PPacket_PacketType.INVITE_REQ
        ..requestId = 'req-1'
        ..senderId = 'joiner'
        ..payload = utf8.encode(inviteCode);

      await handler.handleInviteReq(inviteRoomName, packet);

      expect(crdt.puts.length, 2);
      expect(crdt.puts.map((p) => p.key).toSet(), {
        'group_settings',
        'group_settings:legacy',
      });
      for (final put in crdt.puts) {
        final written = jsonDecode(put.value) as Map<String, dynamic>;
        final invites = (written['invites'] as List).cast<Map>();
        expect(invites.where((i) => i['code'] == inviteCode), isEmpty);
      }
    });
  });
}
