import 'package:cohortz/slices/sync/runtime/crdt_service_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sql_crdt/sql_crdt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitForPersistence() {
    return Future<void>.delayed(const Duration(milliseconds: 180));
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists chat rows across service reinitialization', () async {
    final first = CrdtService();
    await first.initialize('node-a', 'room-a', databaseName: 'group-a');
    await first.put(
      'room-a',
      'msg-1',
      '{"text":"hello"}',
      tableName: 'chat_messages',
    );
    await waitForPersistence();

    final second = CrdtService();
    await second.initialize('node-a', 'room-a', databaseName: 'group-a');
    final rows = await second.query(
      'room-a',
      'SELECT id, value FROM chat_messages WHERE is_deleted = 0',
    );

    expect(rows, hasLength(1));
    expect(rows.first['id'], 'msg-1');
    expect(rows.first['value'], '{"text":"hello"}');
  });

  test('persists merged remote rows across service reinitialization', () async {
    final first = CrdtService();
    await first.initialize('node-a', 'room-a', databaseName: 'group-a');
    await first.merge('room-a', {
      'chat_messages': [
        {
          'id': 'msg-remote',
          'value': '{"text":"from-peer"}',
          'node_id': 'peer-node',
          'hlc': Hlc.now('peer-node'),
          'is_deleted': 0,
        },
      ],
    });
    await waitForPersistence();

    final second = CrdtService();
    await second.initialize('node-a', 'room-a', databaseName: 'group-a');
    final rows = await second.query(
      'room-a',
      'SELECT id, value FROM chat_messages WHERE is_deleted = 0',
    );

    expect(rows, hasLength(1));
    expect(rows.first['id'], 'msg-remote');
  });

  test(
    'shares persisted backing state for room aliases with databaseName',
    () async {
      final first = CrdtService();
      await first.initialize(
        'node-a',
        'invite-room-alias',
        databaseName: 'group-backing-room',
      );
      await first.put(
        'invite-room-alias',
        'msg-1',
        '{"text":"alias"}',
        tableName: 'chat_messages',
      );
      await waitForPersistence();

      final second = CrdtService();
      await second.initialize(
        'node-a',
        'data-room-alias',
        databaseName: 'group-backing-room',
      );
      final rows = await second.query(
        'data-room-alias',
        'SELECT id FROM chat_messages WHERE is_deleted = 0',
      );

      expect(rows, hasLength(1));
      expect(rows.first['id'], 'msg-1');
    },
  );
}
