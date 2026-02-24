import 'dart:io';

import 'package:cohortz/shared/database/crdt/encrypted_sqlite_crdt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sql_crdt/sql_crdt.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('merge repairs legacy avatar_blobs table without primary key', () async {
    final tempDir = await Directory.systemTemp.createTemp('crdt-legacy-');
    final dbPath = '${tempDir.path}/legacy.db';

    EncryptedSqliteCrdt? crdt;
    try {
      final setupDb = sqlite3.open(dbPath);
      setupDb.execute('''
          CREATE TABLE avatar_blobs (
            id TEXT NOT NULL,
            value TEXT,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            hlc TEXT NOT NULL,
            node_id TEXT,
            modified TEXT
          )
        ''');
      setupDb.dispose();

      crdt = await EncryptedSqliteCrdt.open(dbPath);
      final incomingHlc = Hlc.zero('peer-a').increment();

      await crdt.merge({
        'avatar_blobs': [
          {
            'id': 'avatar-1',
            'value': 'new-avatar-value',
            'is_deleted': 0,
            'hlc': incomingHlc,
            'node_id': 'peer-a',
            'modified': incomingHlc,
          },
        ],
      });

      final rows = await crdt.query(
        'SELECT value FROM avatar_blobs WHERE id = ?1',
        ['avatar-1'],
      );
      expect(rows.single['value'], 'new-avatar-value');

      final uniqueIndexes = await crdt.query(
        'SELECT name FROM pragma_index_list(?1) WHERE "unique" = 1',
        ['avatar_blobs'],
      );
      expect(uniqueIndexes, isNotEmpty);
    } finally {
      await crdt?.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}
