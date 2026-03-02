import 'dart:async';
import 'dart:convert';

import 'package:cohortz/shared/database/database.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sql_crdt/sql_crdt.dart';
import 'hlc_compat.dart';

typedef VectorClock = Map<String, String>;

class CrdtService extends ChangeNotifier {
  static const String _roomStoragePrefix = 'crdt_web_room_v1_';
  final Map<String, _WebRoomState> _rooms = {};
  final Map<String, _WebRoomState> _roomsByStorageKey = {};
  final Map<String, String> _storageKeyByRoom = {};
  final Map<String, Future<void>> _initializationFutures = {};
  final Map<String, StreamController<Uint8List>> _updateControllers = {};
  final Map<String, StreamController<Set<String>>> _changeControllers = {};
  final Map<String, Timer> _pendingPersistTimers = {};
  SharedPreferences? _prefs;
  Future<void>? _prefsInitializationFuture;

  Stream<Uint8List> getStream(String roomName) {
    _updateControllers.putIfAbsent(
      roomName,
      () => StreamController<Uint8List>.broadcast(),
    );
    return _updateControllers[roomName]!.stream;
  }

  Stream<Set<String>> _getChangeStream(String roomName) {
    _changeControllers.putIfAbsent(
      roomName,
      () => StreamController<Set<String>>.broadcast(),
    );
    return _changeControllers[roomName]!.stream;
  }

  Future<void> initialize(
    String nodeId,
    String roomName, {
    String? basePath,
    String? databaseName,
  }) async {
    final storageRoomName = _effectiveStorageRoomName(roomName, databaseName);
    final storageKey = _storageKeyForRoom(storageRoomName);
    final key = '$roomName:$storageKey';
    if (_initializationFutures.containsKey(key)) {
      return _initializationFutures[key];
    }

    final future = Future<void>(() async {
      final existing = _roomsByStorageKey[storageKey];
      if (existing != null) {
        existing.nodeId = nodeId;
        _rooms[roomName] = existing;
      } else {
        final restored = await _restoreRoom(storageKey);
        final room =
            restored ?? _WebRoomState(nodeId: nodeId, storageKey: storageKey);
        room.nodeId = nodeId;
        _roomsByStorageKey[storageKey] = room;
        _rooms[roomName] = room;
      }
      _storageKeyByRoom[roomName] = storageKey;
      _updateControllers.putIfAbsent(
        roomName,
        () => StreamController<Uint8List>.broadcast(),
      );
      _changeControllers.putIfAbsent(
        roomName,
        () => StreamController<Set<String>>.broadcast(),
      );
    });

    _initializationFutures[key] = future;
    await future;
  }

  Future<void> put(
    String roomName,
    String key,
    String value, {
    String tableName = 'cohrtz',
  }) async {
    final room = _ensureRoom(roomName);
    final table = room.tables.putIfAbsent(tableName, () => {});
    final record = _WebRecord(
      id: key,
      value: value,
      nodeId: room.nodeId,
      hlc: Hlc.now(room.nodeId),
      isDeleted: false,
    );
    table[key] = record;
    _emitLocalChangeset(roomName, {
      tableName: [record.toCrdtRecord()],
    });
    _emitRoomChanged(roomName, {tableName.toLowerCase()});
    _schedulePersist(roomName);
  }

  Future<void> delete(String roomName, String key, String tableName) async {
    final room = _rooms[roomName];
    if (room == null) return;

    final table = room.tables.putIfAbsent(tableName, () => {});
    final existing = table[key];
    final record = _WebRecord(
      id: key,
      value: '',
      nodeId: room.nodeId,
      hlc: Hlc.now(room.nodeId),
      isDeleted: true,
    );

    if (existing != null && existing.hlc > record.hlc) {
      return;
    }

    table[key] = record;
    _emitLocalChangeset(roomName, {
      tableName: [record.toCrdtRecord()],
    });
    _emitRoomChanged(roomName, {tableName.toLowerCase()});
    _schedulePersist(roomName);
  }

  Future<String?> get(
    String roomName,
    String key, {
    String tableName = 'cohrtz',
  }) async {
    final record = _rooms[roomName]?.tables[tableName]?[key];
    if (record == null || record.isDeleted) return null;
    return record.value;
  }

  Future<void> merge(String roomName, CrdtChangeset changeset) async {
    final room = _ensureRoom(roomName);
    final changedTables = <String>{};

    for (final tableEntry in changeset.entries) {
      final table = room.tables.putIfAbsent(tableEntry.key, () => {});
      for (final rawRecord in tableEntry.value) {
        final record = _WebRecord.fromAny(
          rawRecord,
          defaultNodeId: room.nodeId,
        );
        final existing = table[record.id];
        final shouldReplace =
            existing == null ||
            record.hlc > existing.hlc ||
            (record.hlc == existing.hlc &&
                (record.value != existing.value ||
                    record.isDeleted != existing.isDeleted ||
                    record.nodeId != existing.nodeId));
        if (shouldReplace) {
          table[record.id] = record;
          changedTables.add(tableEntry.key.toLowerCase());
        }
      }
    }

    if (changedTables.isNotEmpty) {
      _emitRoomChanged(roomName, changedTables);
      _schedulePersist(roomName);
    }
  }

  AppDatabase? getDatabase(String roomName) => null;

  Future<List<Map<String, Object?>>> query(
    String roomName,
    String sql, [
    List<Object?>? args,
  ]) async {
    final room = _rooms[roomName];
    if (room == null) return [];

    final normalized = sql.trim().replaceAll(RegExp(r'\s+'), ' ');
    final countMatch = RegExp(
      r'^SELECT\s+count\(\*\)\s+as\s+([a-zA-Z_][a-zA-Z0-9_]*)\s+FROM\s+([a-zA-Z_][a-zA-Z0-9_]*)$',
      caseSensitive: false,
    ).firstMatch(normalized);

    if (countMatch != null) {
      final alias = countMatch.group(1)!;
      final tableName = countMatch.group(2)!;
      final count =
          room.tables[tableName]?.values.where((r) => !r.isDeleted).length ?? 0;
      return [
        {alias: count},
      ];
    }

    final selectMatch = RegExp(
      r'^SELECT\s+(.+?)\s+FROM\s+([a-zA-Z_][a-zA-Z0-9_]*)(?:\s+WHERE\s+(.+?))?(?:\s+LIMIT\s+(\d+))?$',
      caseSensitive: false,
    ).firstMatch(normalized);

    if (selectMatch == null) {
      debugPrint('[CrdtService(web)] Unsupported query: $sql');
      return [];
    }

    final columnsSpec = selectMatch.group(1)!.trim();
    final tableName = selectMatch.group(2)!.trim();
    final whereClause = selectMatch.group(3)?.trim().toLowerCase();
    final limit = int.tryParse(selectMatch.group(4) ?? '');

    final rawRows =
        room.tables[tableName]?.values.toList() ?? const <_WebRecord>[];
    final filtered = rawRows.where((record) {
      if (whereClause == null || whereClause.isEmpty) {
        return true;
      }

      if (whereClause.contains('is_deleted = 0') && record.isDeleted) {
        return false;
      }

      if (whereClause.contains('id = ?')) {
        final expected = args != null && args.isNotEmpty ? args.first : null;
        return record.id == expected;
      }

      return true;
    }).toList();

    final projected = filtered.map((record) {
      final row = record.toRowMap();
      if (columnsSpec == '*') {
        return row;
      }

      final selectedColumns = columnsSpec
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final projectedRow = <String, Object?>{};
      for (final column in selectedColumns) {
        projectedRow[column] = row[column];
      }
      return projectedRow;
    }).toList();

    if (limit == null || limit >= projected.length) {
      return projected;
    }
    return projected.take(limit).toList();
  }

  Stream<List<Map<String, Object?>>> watch(
    String roomName,
    String sql, [
    List<Object?>? args,
  ]) async* {
    final referencedTables = _tablesReferencedBySql(sql);
    yield await query(roomName, sql, args);
    await for (final changedTables in _getChangeStream(roomName)) {
      if (!_shouldRefreshQuery(changedTables, referencedTables)) {
        continue;
      }
      yield await query(roomName, sql, args);
    }
  }

  Future<CrdtChangeset> getChangeset(String roomName, {Hlc? after}) async {
    final room = _rooms[roomName];
    if (room == null) return {};

    final changeset = <String, List<CrdtRecord>>{};
    for (final tableEntry in room.tables.entries) {
      final rows = tableEntry.value.values
          .where((record) => after == null || record.hlc > after)
          .map((record) => record.toCrdtRecord())
          .toList();
      if (rows.isNotEmpty) {
        changeset[tableEntry.key] = rows;
      }
    }
    return changeset;
  }

  Future<VectorClock> getVectorClock(String roomName) async {
    final room = _rooms[roomName];
    if (room == null) return {};

    final vectorClock = <String, String>{};
    for (final table in room.tables.values) {
      for (final record in table.values) {
        final existing = vectorClock[record.nodeId];
        if (existing == null || record.hlc > parseHlcCompat(existing)) {
          vectorClock[record.nodeId] = record.hlc.toString();
        }
      }
    }
    return vectorClock;
  }

  Future<CrdtChangeset> getChangesetFromVector(
    String roomName,
    VectorClock remoteVectorClock,
  ) async {
    final room = _rooms[roomName];
    if (room == null) return {};

    final changeset = <String, List<CrdtRecord>>{};
    for (final tableEntry in room.tables.entries) {
      final rows = tableEntry.value.values
          .where((record) {
            final remoteHlcStr = remoteVectorClock[record.nodeId];
            if (remoteHlcStr == null) return true;
            return record.hlc > parseHlcCompat(remoteHlcStr);
          })
          .map((record) => record.toCrdtRecord())
          .toList();

      if (rows.isNotEmpty) {
        changeset[tableEntry.key] = rows;
      }
    }
    return changeset;
  }

  Future<String> calculateMerkleRoot(String roomName) async {
    final room = _rooms[roomName];
    if (room == null) return '';

    final hashes = <String>[];
    for (final table in room.tables.values) {
      for (final record in table.values) {
        final content = '${record.id}|${record.value}|${record.hlc}';
        hashes.add(sha256.convert(utf8.encode(content)).toString());
      }
    }

    if (hashes.isEmpty) return 'empty';
    hashes.sort();
    return sha256.convert(utf8.encode(hashes.join(':'))).toString();
  }

  Future<Map<String, dynamic>> getDiagnostics(String roomName) async {
    final room = _rooms[roomName];
    if (room == null) return {};

    var count = 0;
    for (final table in room.tables.values) {
      count += table.values.where((record) => !record.isDeleted).length;
    }

    return {'count': count, 'hash': await calculateMerkleRoot(roomName)};
  }

  Future<int> getDatabaseSize(String roomName) async {
    return getLogicalSize(roomName);
  }

  Future<int> getLogicalSize(String roomName) async {
    final room = _rooms[roomName];
    if (room == null) return 0;

    var total = 0;
    for (final table in room.tables.values) {
      for (final record in table.values) {
        if (record.isDeleted) continue;
        total += record.id.length + record.value.length + 40;
      }
    }
    return total;
  }

  Future<void> deleteDatabase(String roomName, {String? databaseName}) async {
    final storageRoomName = _effectiveStorageRoomName(roomName, databaseName);
    final storageKey =
        _storageKeyByRoom.remove(roomName) ??
        _storageKeyForRoom(storageRoomName);

    _rooms.remove(roomName);

    final updateController = _updateControllers.remove(roomName);
    await updateController?.close();
    final changeController = _changeControllers.remove(roomName);
    await changeController?.close();

    final hasRemainingAlias = _storageKeyByRoom.values.contains(storageKey);
    if (!hasRemainingAlias) {
      _roomsByStorageKey.remove(storageKey);
      _pendingPersistTimers.remove(storageKey)?.cancel();
      final prefs = await _getPrefs();
      await prefs.remove('$_roomStoragePrefix$storageKey');
    }

    notifyListeners();
  }

  _WebRoomState _ensureRoom(String roomName) {
    final existing = _rooms[roomName];
    if (existing != null) return existing;

    final storageKey = _storageKeyByRoom.putIfAbsent(
      roomName,
      () => _storageKeyForRoom(roomName),
    );
    final room = _roomsByStorageKey.putIfAbsent(
      storageKey,
      () => _WebRoomState(nodeId: 'web', storageKey: storageKey),
    );
    _rooms[roomName] = room;
    return room;
  }

  void _emitLocalChangeset(String roomName, CrdtChangeset changeset) {
    final payload = Uint8List.fromList(
      utf8.encode(
        jsonEncode(
          changeset,
          toEncodable: (value) => value is Hlc ? value.toString() : value,
        ),
      ),
    );

    _updateControllers[roomName]?.add(payload);
  }

  void _emitRoomChanged(String roomName, Set<String> changedTables) {
    if (changedTables.isEmpty) return;
    _changeControllers[roomName]?.add(changedTables);
    notifyListeners();
  }

  String _effectiveStorageRoomName(String roomName, String? databaseName) {
    if (databaseName == null || databaseName.trim().isEmpty) {
      return roomName;
    }
    return databaseName;
  }

  String _storageKeyForRoom(String roomName) => Uri.encodeComponent(roomName);

  Future<SharedPreferences> _getPrefs() async {
    if (_prefs != null) return _prefs!;
    if (_prefsInitializationFuture != null) {
      await _prefsInitializationFuture;
      return _prefs!;
    }

    final future = Future<void>(() async {
      _prefs = await SharedPreferences.getInstance();
    });
    _prefsInitializationFuture = future;
    try {
      await future;
    } finally {
      _prefsInitializationFuture = null;
    }
    return _prefs!;
  }

  Future<_WebRoomState?> _restoreRoom(String storageKey) async {
    try {
      final prefs = await _getPrefs();
      final encoded = prefs.getString('$_roomStoragePrefix$storageKey');
      if (encoded == null || encoded.isEmpty) return null;

      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?>) return null;
      return _WebRoomState.fromJson(decoded, storageKey: storageKey);
    } catch (error) {
      debugPrint('[CrdtService(web)] Failed to restore room: $error');
      return null;
    }
  }

  void _schedulePersist(String roomName) {
    final storageKey = _storageKeyByRoom[roomName];
    if (storageKey == null) return;

    _pendingPersistTimers.remove(storageKey)?.cancel();
    _pendingPersistTimers[storageKey] = Timer(
      const Duration(milliseconds: 120),
      () {
        _pendingPersistTimers.remove(storageKey);
        unawaited(_persistStorageKey(storageKey));
      },
    );
  }

  Future<void> _persistStorageKey(String storageKey) async {
    final room = _roomsByStorageKey[storageKey];
    if (room == null) return;

    try {
      final prefs = await _getPrefs();
      await prefs.setString(
        '$_roomStoragePrefix$storageKey',
        jsonEncode(room.toJson()),
      );
    } catch (error) {
      debugPrint('[CrdtService(web)] Failed to persist room: $error');
    }
  }

  bool _shouldRefreshQuery(
    Set<String> changedTables,
    Set<String> referencedTables,
  ) {
    if (changedTables.isEmpty || referencedTables.isEmpty) {
      return true;
    }
    for (final table in changedTables) {
      if (referencedTables.contains(table)) {
        return true;
      }
    }
    return false;
  }

  Set<String> _tablesReferencedBySql(String sql) {
    final normalized = sql.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    final tables = <String>{};

    for (final match in RegExp(
      r'\bfrom\s+([a-zA-Z_][a-zA-Z0-9_]*)',
    ).allMatches(normalized)) {
      final table = match.group(1);
      if (table != null && table.isNotEmpty) {
        tables.add(table);
      }
    }

    for (final match in RegExp(
      r'\bjoin\s+([a-zA-Z_][a-zA-Z0-9_]*)',
    ).allMatches(normalized)) {
      final table = match.group(1);
      if (table != null && table.isNotEmpty) {
        tables.add(table);
      }
    }

    return tables;
  }
}

class _WebRoomState {
  _WebRoomState({required this.nodeId, required this.storageKey});

  String nodeId;
  final String storageKey;
  final Map<String, Map<String, _WebRecord>> tables = {};

  Map<String, Object?> toJson() {
    final encodedTables = <String, List<Map<String, Object?>>>{};
    for (final entry in tables.entries) {
      encodedTables[entry.key] = entry.value.values
          .map((record) => record.toStorageMap())
          .toList();
    }
    return {'nodeId': nodeId, 'tables': encodedTables};
  }

  factory _WebRoomState.fromJson(
    Map<String, Object?> json, {
    required String storageKey,
  }) {
    final state = _WebRoomState(
      nodeId: (json['nodeId'] as String?) ?? 'web',
      storageKey: storageKey,
    );

    final rawTables = json['tables'];
    if (rawTables is Map) {
      for (final entry in rawTables.entries) {
        final tableName = entry.key?.toString();
        if (tableName == null || tableName.isEmpty) continue;
        final records = <String, _WebRecord>{};
        final rawRows = entry.value;
        if (rawRows is List) {
          for (final row in rawRows) {
            if (row is Map<String, Object?>) {
              final record = _WebRecord.fromAny(
                row,
                defaultNodeId: state.nodeId,
              );
              if (record.id.isEmpty) continue;
              records[record.id] = record;
            } else if (row is Map) {
              final normalized = <String, Object?>{};
              for (final item in row.entries) {
                final key = item.key?.toString();
                if (key == null || key.isEmpty) continue;
                normalized[key] = item.value;
              }
              final record = _WebRecord.fromAny(
                normalized,
                defaultNodeId: state.nodeId,
              );
              if (record.id.isEmpty) continue;
              records[record.id] = record;
            }
          }
        }
        if (records.isNotEmpty) {
          state.tables[tableName] = records;
        }
      }
    }

    return state;
  }
}

class _WebRecord {
  _WebRecord({
    required this.id,
    required this.value,
    required this.nodeId,
    required this.hlc,
    required this.isDeleted,
  });

  final String id;
  final String value;
  final String nodeId;
  final Hlc hlc;
  final bool isDeleted;

  Map<String, Object?> toRowMap() => {
    'id': id,
    'value': value,
    'node_id': nodeId,
    'hlc': hlc.toString(),
    'is_deleted': isDeleted ? 1 : 0,
  };

  CrdtRecord toCrdtRecord() => {
    'id': id,
    'value': value,
    'node_id': nodeId,
    'hlc': hlc,
    'is_deleted': isDeleted ? 1 : 0,
  };

  Map<String, Object?> toStorageMap() => {
    'id': id,
    'value': value,
    'node_id': nodeId,
    'hlc': hlc.toString(),
    'is_deleted': isDeleted ? 1 : 0,
  };

  factory _WebRecord.fromAny(
    Map<String, Object?> record, {
    required String defaultNodeId,
  }) {
    final id = (record['id'] ?? '').toString();
    final value = (record['value'] ?? '').toString();
    final nodeId = (record['node_id'] ?? defaultNodeId).toString();
    final hlcRaw = record['hlc'];
    final hlc = hlcRaw is Hlc ? hlcRaw : parseHlcCompat(hlcRaw.toString());
    final deletedRaw = record['is_deleted'];
    final isDeleted =
        deletedRaw == true || deletedRaw == 1 || deletedRaw == '1';

    return _WebRecord(
      id: id,
      value: value,
      nodeId: nodeId,
      hlc: hlc,
      isDeleted: isDeleted,
    );
  }
}
