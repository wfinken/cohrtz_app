import 'dart:async';
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:cohortz/shared/database/crdt/encrypted_sqlite_crdt.dart';
import 'package:cohortz/shared/security/secure_storage_service.dart';
import 'package:cohortz/shared/security/encryption_service.dart';
import 'package:sql_crdt/sql_crdt.dart';

import '../../../shared/utils/logging_service.dart';
import '../../../shared/database/database.dart';
import '../../../shared/database/crdt_executor.dart';
import 'package:drift/drift.dart' as drift;

typedef VectorClock = Map<String, String>;

class CrdtService extends ChangeNotifier {
  final Map<String, SqlCrdt> _crdts = {};
  final Map<String, AppDatabase> _driftDbs = {};
  String? _dbKey; // Device-specific encryption key

  // Track initialization to prevent concurrent setup races
  final Map<String, Future<void>> _initializationFutures = {};

  // Stream of changeset updates (JSON strings or binary) per room
  // Key: RoomName, Value: StreamController
  final Map<String, StreamController<Uint8List>> _updateControllers = {};

  // Reverse mapping: instanceKey -> Set of roomNames that use this instance
  // This ensures broadcasts reach all subscribers regardless of which roomName they used
  final Map<String, Set<String>> _instanceToRoomNames = {};

  Stream<Uint8List> getStream(String roomName) {
    _updateControllers.putIfAbsent(
      roomName,
      () => StreamController<Uint8List>.broadcast(),
    );
    return _updateControllers[roomName]!.stream;
  }

  Future<void> initialize(
    String nodeId,
    String roomName, {
    String? basePath,
    String? databaseName,
  }) async {
    final key = '$roomName:${databaseName ?? ""}';
    if (_initializationFutures.containsKey(key)) {
      return _initializationFutures[key];
    }

    final future = _initializeInternal(
      nodeId,
      roomName,
      basePath: basePath,
      databaseName: databaseName,
    );
    _initializationFutures[key] = future;
    return future;
  }

  Future<void> _initializeInternal(
    String nodeId,
    String roomName, {
    String? basePath,
    String? databaseName,
  }) async {
    // Optionally silence drift warning if multiple databases are intended
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    if (_crdts.containsKey(roomName)) return;

    String path;
    final effectiveDbName = databaseName ?? roomName;
    final sanitizedName = effectiveDbName.replaceAll(RegExp(r'[^\w]'), '_');
    final dbFilename = 'cohrtz_$sanitizedName.db';
    final instanceKey =
        sanitizedName; // Use sanitized name as the key for instance tracking

    if (_crdts.containsKey(instanceKey)) {
      // Map this roomName to the existing instance if it's different
      if (roomName != instanceKey) {
        // We only return if the instance is already fully initialized.
        // If it's in progress, we might have a race, but CrdtService is usually
        // called sequentially or guarded by higher level logic.
        _crdts[roomName] = _crdts[instanceKey]!;
        _driftDbs[roomName] = _driftDbs[instanceKey]!;
        // Track this roomName as using this instance
        _instanceToRoomNames.putIfAbsent(instanceKey, () => {}).add(roomName);
      }
      return;
    }
    if (basePath != null) {
      path = p.join(basePath, dbFilename);
    } else if (kIsWeb) {
      path = dbFilename;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}/$dbFilename';
    }

    // Secure Key Management
    if (!kIsWeb && _dbKey == null) {
      final secureStorage = SecureStorageService();
      _dbKey = await secureStorage.read('device_db_key');
      if (_dbKey == null) {
        // Generate new secure key (32 bytes hex encoded or base64)
        // Using EncryptionService to get secure random bytes
        final encryptionService = EncryptionService();
        final salt = await encryptionService.generateSalt();
        final salt2 = await encryptionService.generateSalt();
        // Combine to get 32 bytes
        _dbKey = base64Encode([...salt, ...salt2]);
        await secureStorage.write('device_db_key', _dbKey!);
        // Log.d('CrdtService', 'Generated and saved new device DB key');
      } else {
        // Log.d('CrdtService', 'Loaded device DB key');
      }
    }

    EncryptedSqliteCrdt crdt;
    try {
      crdt = await EncryptedSqliteCrdt.open(path, password: _dbKey);
    } on SqliteException catch (e) {
      if (e.extendedResultCode == 26) {
        // File is not a database
        Log.e(
          'CrdtService',
          'Database file corrupted or not a database: $path. Deleting and recreating.',
          e,
        );
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
        // Retry open
        crdt = await EncryptedSqliteCrdt.open(path, password: _dbKey);
      } else {
        rethrow;
      }
    }
    crdt.onDatasetChangedCallback = (tables, hlc) async {
      // Log.d(
      //   'CrdtService',
      //   'onDatasetChangedCallback triggered for instanceKey=$instanceKey, tables=$tables',
      // );
      Log.d(
        'CrdtService',
        'onDatasetChangedCallback: instance=$instanceKey, tables=$tables, triggerHlc=$hlc',
      );
      if (tables.contains('tasks') || tables.contains('notes')) {
        Log.i(
          'CrdtService',
          'Broadcasting change for sensitive tables: $tables',
        );
      }
      final changeset = await crdt.getChangeset(
        onlyTables: tables,
        modifiedOn: hlc,
      );

      // FILTER: Only broadcast changes created by THIS node.
      // This prevents infinite loops where Peer A sends to B, B merges and rebroadcasts back to A.
      // IMPORTANT: Use crdt.nodeId (the CRDT's internal node ID), not _nodeId (user ID)
      final crdtNodeId = crdt.nodeId;
      final localRecords = <String, List<CrdtRecord>>{};
      for (var entry in changeset.entries) {
        final filtered = entry.value
            .where((r) => r['node_id'] == crdtNodeId)
            .toList();
        if (filtered.isNotEmpty) {
          localRecords[entry.key] = filtered;
        }
      }

      if (localRecords.isNotEmpty) {
        final tablesInBroadcast = localRecords.keys.toList();
        Log.d(
          'CrdtService',
          'Broadcasting local changes for tables: $tablesInBroadcast',
        );
        final payload = utf8.encode(
          jsonEncode(
            localRecords,
            toEncodable: (nonEncodable) {
              if (nonEncodable is Hlc) return nonEncodable.toString();
              return nonEncodable;
            },
          ),
        );
        // Broadcast to ALL room names that share this CRDT instance
        final roomsForInstance = _instanceToRoomNames[instanceKey] ?? {};
        for (final room in roomsForInstance) {
          final controller = _updateControllers[room];
          if (controller != null) {
            controller.add(payload);
          }
          // We no longer log "No controller found" here because it's common
          // to have initialized a CRDT but not yet subscribed to it (e.g. background rooms).
        }
      } else {
        // Log.d(
        //   'CrdtService',
        //   'No local records to broadcast (changes from other nodes)',
        // );
      }
      notifyListeners();
    };
    _crdts[instanceKey] = crdt;
    _driftDbs[instanceKey] = AppDatabase(CrdtQueryExecutor(crdt));

    // Track that this instanceKey is used by these room names
    _instanceToRoomNames.putIfAbsent(instanceKey, () => {}).add(instanceKey);
    // Eagerly create stream controller so onDatasetChangedCallback finds it
    _updateControllers.putIfAbsent(
      instanceKey,
      () => StreamController<Uint8List>.broadcast(),
    );
    if (roomName != instanceKey) {
      _instanceToRoomNames[instanceKey]!.add(roomName);
      _updateControllers.putIfAbsent(
        roomName,
        () => StreamController<Uint8List>.broadcast(),
      );
    }
    // Log.d(
    //   'CrdtService',
    //   'Initialized CRDT for instanceKey=$instanceKey, tracking rooms: ${_instanceToRoomNames[instanceKey]}',
    // );

    // Also map by roomName for current context access
    if (roomName != instanceKey) {
      _crdts[roomName] = crdt;
      _driftDbs[roomName] = _driftDbs[instanceKey]!;
    }

    // Create typed tables
    final tables = [
      'tasks',
      'calendar_events',
      'vault_items',
      'chat_messages',
      'chat_threads',
      'user_profiles',
      'members',
      'roles',
      'group_settings',
      'dashboard_widgets',
      'notes',
      'polls',
    ];

    for (final table in tables) {
      await crdt.execute('''
        CREATE TABLE IF NOT EXISTS $table (
          id TEXT NOT NULL,
          value TEXT,
          PRIMARY KEY (id)
        )
      ''');
    }

    await crdt.execute('''
      CREATE TABLE IF NOT EXISTS cohrtz (
        id TEXT NOT NULL,
        value TEXT,
        PRIMARY KEY (id)
      )
    ''');

    await crdt.execute('''
      CREATE TABLE IF NOT EXISTS groupman (
        id TEXT NOT NULL,
        value TEXT,
        PRIMARY KEY (id)
      )
    ''');

    final legacyRecords = await crdt.query('SELECT id, value FROM groupman');
    if (legacyRecords.isNotEmpty) {
      Log.i(
        'CrdtService',
        'Migrating ${legacyRecords.length} records from groupman table...',
      );
      for (final row in legacyRecords) {
        final id = row['id'] as String;
        final value = row['value'] as String;

        // Determine target table based on prefix
        String? targetTable;
        if (id.startsWith('task:')) {
          targetTable = 'tasks';
        } else if (id.startsWith('event:')) {
          targetTable = 'calendar_events';
        } else if (id.startsWith('vault:')) {
          targetTable = 'vault_items';
        } else if (id.startsWith('msg:')) {
          targetTable = 'chat_messages';
        } else if (id.startsWith('user:')) {
          targetTable = 'user_profiles';
        } else if (id.startsWith('group_settings:')) {
          targetTable = 'group_settings';
        } else if (id.startsWith('widget:')) {
          targetTable = 'dashboard_widgets';
        } else if (id.startsWith('note:')) {
          targetTable = 'notes';
        } else if (id.startsWith('poll:')) {
          targetTable = 'polls';
        }

        if (targetTable != null) {
          await crdt.execute(
            'INSERT OR IGNORE INTO $targetTable (id, value) VALUES (?, ?)',
            [id, value],
          );

          final migrated = await crdt.query(
            'SELECT * FROM $targetTable WHERE id = ?',
            [id],
          );
          if (migrated.isNotEmpty) {
            final changeset = {
              targetTable: [migrated.first],
            };
            final payload = utf8.encode(
              jsonEncode(
                changeset,
                toEncodable: (nonEncodable) {
                  if (nonEncodable is Hlc) return nonEncodable.toString();
                  return nonEncodable;
                },
              ),
            );
            _updateControllers[roomName]?.add(payload);
          }
        }
      }
      Log.i('CrdtService', 'Migration complete and broadcasted.');
    }
  }

  Future<void> put(
    String roomName,
    String key,
    String value, {
    String tableName = 'cohrtz',
  }) async {
    final crdt = _crdts[roomName];
    if (crdt == null) return;

    await crdt.execute(
      '''
      INSERT INTO $tableName (id, value) VALUES (?1, ?2) 
      ON CONFLICT(id) DO UPDATE SET value = ?2
    ''',
      [key, value],
    );
  }

  Future<void> delete(String roomName, String key, String tableName) async {
    Log.d(
      'CrdtService',
      'delete called for $key in table $tableName (room: $roomName)',
    );
    final crdt = _crdts[roomName];
    if (crdt == null) {
      Log.w('CrdtService', 'crdt instance not found for room $roomName');
      return;
    }

    try {
      await crdt.transaction((txn) async {
        // 1. Scrub the data (Privacy/Storage)
        // We update the value to empty string so the physical payload is removed
        // even if the record stays as a tombstone.
        await txn.execute('UPDATE $tableName SET value = ? WHERE id = ?', [
          '',
          key,
        ]);

        // 2. Perform the logical delete (CRDT Tombstone)
        await txn.execute('DELETE FROM $tableName WHERE id = ?', [key]);
      });

      // 3. Broadcast handling
      // We rely on onDatasetChangedCallback to broadcast the deletion
      // which is more robust and avoids duplicate logic.
    } catch (e) {
      Log.e('CrdtService', 'Error during DELETE transaction', e);
    }

    // Notify Drift watchers that the table has changed
    final db = _driftDbs[roomName];
    if (db != null) {
      final changedTables = db.allTables.where(
        (t) => t.actualTableName == tableName,
      );
      if (changedTables.isNotEmpty) {
        db.markTablesUpdated(changedTables);
        // Log.d('CrdtService', 'Notified Drift watcher for delete on $tableName');
      }
    }

    notifyListeners();
  }

  Future<String?> get(
    String roomName,
    String key, {
    String tableName = 'cohrtz',
  }) async {
    final crdt = _crdts[roomName];
    if (crdt == null) return null;
    final result = await crdt.query(
      'SELECT value FROM $tableName WHERE id = ?',
      [key],
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  Future<void> merge(String roomName, CrdtChangeset changeset) async {
    final crdt = _crdts[roomName];
    if (crdt == null) return;
    await crdt.merge(changeset);
    // --- DIAGNOSTIC: raw query after merge ---
    for (final table in changeset.keys) {
      if (table == 'cohrtz') continue; // skip internal CRDT table
      try {
        final allRows = await crdt.query(
          'SELECT id, is_deleted, value, node_id, hlc FROM $table',
        );
        debugPrint('[CrdtService] DIAG $table: ${allRows.length} total rows');
        for (final row in allRows) {
          final val = row['value'] as String?;
          final valPrint = val == null
              ? 'null'
              : (val.length > 20 ? '${val.substring(0, 20)}...' : val);
          debugPrint(
            '[CrdtService]   id=${row['id']}, '
            'is_deleted=${row['is_deleted']}, '
            'value=$valPrint, '
            'node_id=${(row['node_id'] as String?)?.substring(0, 8) ?? 'null'}..., '
            'hlc=${(row['hlc'] as String?)?.substring(0, 20) ?? 'null'}...',
          );
        }
      } catch (e) {
        debugPrint('[CrdtService] DIAG error querying $table: $e');
      }
    }
    // --- END DIAGNOSTIC ---
    // Notify Drift watchers that tables have changed
    final db = _driftDbs[roomName];
    if (db != null) {
      final changedTableNames = changeset.keys.toSet();
      final changedTables = db.allTables.where(
        (t) => changedTableNames.contains(t.actualTableName),
      );
      debugPrint(
        '[CrdtService] merge: changeset tables=$changedTableNames, '
        'matched drift tables=${changedTables.map((t) => t.actualTableName).toList()}, '
        'db hashCode=${db.hashCode}',
      );
      if (changedTables.isNotEmpty) {
        db.markTablesUpdated(changedTables);
        debugPrint('[CrdtService] markTablesUpdated called');
      }
    } else {
      debugPrint('[CrdtService] merge: NO drift db found for room=$roomName');
    }
    notifyListeners();
  }

  AppDatabase? getDatabase(String roomName) => _driftDbs[roomName];

  Future<List<Map<String, Object?>>> query(
    String roomName,
    String sql, [
    List<Object?>? args,
  ]) async {
    final crdt = _crdts[roomName];
    if (crdt == null) return [];
    return crdt.query(sql, args);
  }

  Stream<List<Map<String, Object?>>> watch(
    String roomName,
    String sql, [
    List<Object?>? args,
  ]) {
    final crdt = _crdts[roomName];
    if (crdt == null) return Stream.value([]);
    return crdt.watch(sql, args != null ? () => args : null);
  }

  Future<CrdtChangeset> getChangeset(String roomName, {Hlc? after}) async {
    final crdt = _crdts[roomName];
    if (crdt == null) return {};

    final allChanges = await crdt.getChangeset();

    if (after == null) return allChanges;

    final filtered = <String, List<CrdtRecord>>{};
    for (var entry in allChanges.entries) {
      final records = entry.value
          .where((r) => (r['hlc'] as Hlc) > after)
          .toList();
      if (records.isNotEmpty) {
        filtered[entry.key] = records;
      }
    }
    return filtered;
  }

  Future<VectorClock> getVectorClock(String roomName) async {
    final crdt = _crdts[roomName];
    if (crdt == null) return {};

    final vectorClock = <String, String>{};
    final tables = await crdt.getTables();

    for (final table in tables) {
      if (table.startsWith('sqlite_') || table == 'crsql_changes') continue;
      try {
        final result = await crdt.query(
          'SELECT node_id, MAX(hlc) as max_hlc FROM $table GROUP BY node_id',
        );
        for (final row in result) {
          final nodeId = row['node_id'] as String?;
          final maxHlc = row['max_hlc'] as String?;

          if (nodeId != null && maxHlc != null) {
            final currentMax = vectorClock[nodeId];
            if (currentMax == null ||
                (Hlc.parse(maxHlc) > Hlc.parse(currentMax))) {
              vectorClock[nodeId] = maxHlc;
            }
          }
        }
      } catch (e) {
        Log.w(
          'CrdtService',
          'Error computing vector clock for table $table: $e',
        );
      }
    }
    return vectorClock;
  }

  Future<CrdtChangeset> getChangesetFromVector(
    String roomName,
    VectorClock remoteVectorClock,
  ) async {
    final crdt = _crdts[roomName];
    if (crdt == null) return {};

    final allChanges = await crdt.getChangeset();
    final filtered = <String, List<CrdtRecord>>{};

    for (var entry in allChanges.entries) {
      final records = entry.value.where((r) {
        final hlcVal = r['hlc'];
        final nodeId = r['node_id'] as String?;

        final hlc = hlcVal is Hlc ? hlcVal : Hlc.parse(hlcVal.toString());

        // If we can't determine node origin, send it to be safe
        if (nodeId == null) return true;

        // If remote has a clock for this node
        if (remoteVectorClock.containsKey(nodeId)) {
          final remoteHlcStr = remoteVectorClock[nodeId]!;
          final remoteHlc = Hlc.parse(remoteHlcStr);
          // Include if our data is newer than what they have
          return hlc > remoteHlc;
        }

        // If remote doesn't know this node, they need the data
        return true;
      }).toList();

      if (records.isNotEmpty) {
        filtered[entry.key] = records;
      }
    }
    return filtered;
  }

  /// Calculates a Merkle Root or a combined hash of all records in all tables.
  /// This is used to verify database consistency between peers.
  Future<String> calculateMerkleRoot(String roomName) async {
    final crdt = _crdts[roomName];
    if (crdt == null) return '';

    final tables = [
      'tasks',
      'calendar_events',
      'vault_items',
      'chat_messages',
      'user_profiles',
      'group_settings',
      'dashboard_widgets',
      'notes',
      'polls',
      'cohrtz',
      'groupman',
    ];

    final List<String> recordHashes = [];

    for (final table in tables) {
      // We hash the ID, Value, and HLC (to ensure version consistency)
      final results = await crdt.query(
        'SELECT id, value, hlc FROM $table ORDER BY id ASC',
      );
      for (final row in results) {
        final content = '${row['id']}|${row['value']}|${row['hlc']}';
        recordHashes.add(sha256.convert(utf8.encode(content)).toString());
      }
    }

    if (recordHashes.isEmpty) return 'empty';

    // Simple Merkle-like root by hashing the sorted sequence of leaf hashes
    recordHashes.sort();
    final combined = recordHashes.join(':');
    return sha256.convert(utf8.encode(combined)).toString();
  }

  Future<Map<String, dynamic>> getDiagnostics(String roomName) async {
    final crdt = _crdts[roomName];
    if (crdt == null) return {};

    final hash = await calculateMerkleRoot(roomName);

    // Sum counts from all tables
    int totalCount = 0;
    final tables = [
      'tasks',
      'calendar_events',
      'vault_items',
      'chat_messages',
      'user_profiles',
      'group_settings',
      'dashboard_widgets',
      'notes',
      'polls',
      'cohrtz',
      'groupman',
    ];

    for (final table in tables) {
      final res = await crdt.query('SELECT count(*) as c FROM $table');
      totalCount += (res.first['c'] as int);
    }

    return {'count': totalCount, 'hash': hash};
  }

  Future<int> getDatabaseSize(String roomName) async {
    final crdt = _crdts[roomName];
    if (crdt == null) return 0;

    try {
      // Physical size (coarse, page-based)
      int physical = 0;
      final resPageCount = await crdt.query('PRAGMA page_count');
      final resPageSize = await crdt.query('PRAGMA page_size');

      if (resPageCount.isNotEmpty && resPageSize.isNotEmpty) {
        final pageCount = resPageCount.first['page_count'] as int;
        final pageSize = resPageSize.first['page_size'] as int;
        physical = pageCount * pageSize;
      }

      // Logical size (fine-grained, based on data content)
      // This ensures small updates are visible.
      final logical = await getLogicalSize(roomName);

      // Log.d(
      //   'CrdtService',
      //   'Database size for $roomName: physical $physical, logical $logical',
      // );

      // Return combined physical + logical modulo to ensure UI updates on every change
      return physical + (logical % 1024);
    } catch (e) {
      Log.e('CrdtService', 'Error calculating database size', e);
    }
    return 0;
  }

  Future<int> getLogicalSize(String roomName) async {
    final crdt = _crdts[roomName];
    if (crdt == null) return 0;

    int total = 0;
    final tables = [
      'tasks',
      'calendar_events',
      'vault_items',
      'chat_messages',
      'user_profiles',
      'group_settings',
      'dashboard_widgets',
      'notes',
      'polls',
      'cohrtz',
      'groupman',
    ];

    for (final table in tables) {
      try {
        final res = await crdt.query(
          'SELECT SUM(LENGTH(id) + LENGTH(COALESCE(value, \'\')) + 40) as s FROM $table',
        );
        if (res.isNotEmpty && res.first['s'] != null) {
          total += (res.first['s'] as num).toInt();
        }
      } catch (_) {
        // Table might not exist
      }
    }
    return total;
  }

  Future<void> deleteDatabase(String roomName, {String? databaseName}) async {
    // 1. Close and remove from memory
    final crdt = _crdts.remove(roomName);
    if (crdt != null) {
      try {
        if (crdt is EncryptedSqliteCrdt) {
          await crdt.close();
        }
      } catch (e) {
        Log.w('CrdtService', 'Error closing database for $roomName: $e');
      }
    }

    // 2. Determine path (same logic as initialize)
    String path;
    final effectiveDbName = databaseName ?? roomName;
    final sanitizedName = effectiveDbName.replaceAll(RegExp(r'[^\w]'), '_');
    final dbFilename = 'cohrtz_$sanitizedName.db';

    if (kIsWeb) {
      Log.w('CrdtService', 'Web database deletion not fully supported yet.');
      return;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}/$dbFilename';
    }

    // 3. Delete file
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      Log.i('CrdtService', 'Deleted database file: $path');
    }
  }
}
