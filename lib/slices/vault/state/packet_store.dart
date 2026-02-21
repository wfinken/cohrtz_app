import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:cohortz/shared/utils/logging_service.dart';
import '../models/stored_packet.dart';

class PacketStore extends ChangeNotifier {
  final Map<String, Database> _dbs = {};

  String _sanitizeRoomName(String roomName) {
    return roomName.replaceAll(RegExp(r'[^\w]'), '_');
  }

  Future<Database> _initDb(String roomName) async {
    if (_dbs.containsKey(roomName)) return _dbs[roomName]!;

    if (kIsWeb) {
      throw UnsupportedError(
        'Web support for PacketStore is not yet implemented with sqlite3',
      );
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final sanitized = _sanitizeRoomName(roomName);
    final path = p.join(docsDir.path, 'packet_store_$sanitized.db');

    final db = sqlite3.open(path);
    _dbs[roomName] = db;

    db.execute('''
      CREATE TABLE IF NOT EXISTS packets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        requestId TEXT,
        senderId TEXT,
        timestamp INTEGER,
        payload BLOB,
        packetType INTEGER
      )
    ''');

    return db;
  }

  Future<void> savePacket(String roomName, StoredPacket packet) async {
    final db = await _initDb(roomName);
    final stmt = db.prepare('''
      INSERT INTO packets (requestId, senderId, timestamp, payload, packetType)
      VALUES (?, ?, ?, ?, ?)
    ''');
    stmt.execute([
      packet.requestId,
      packet.senderId,
      packet.timestamp.millisecondsSinceEpoch,
      packet.payload,
      packet.packetType,
    ]);
    stmt.dispose();
    notifyListeners();
  }

  Future<List<StoredPacket>> getAllPackets(String roomName) async {
    final db = await _initDb(roomName);
    final result = db.select('SELECT * FROM packets');
    return result.map((row) => StoredPacket.fromMap(row)).toList();
  }

  Future<int> getStorageSize(String roomName) async {
    final db = await _initDb(roomName);

    try {
      final resPageCount = db.select('PRAGMA page_count');
      final resPageSize = db.select('PRAGMA page_size');

      if (resPageCount.isNotEmpty && resPageSize.isNotEmpty) {
        final pageCount = resPageCount.first['page_count'] as int;
        final pageSize = resPageSize.first['page_size'] as int;
        final physical = pageCount * pageSize;

        // Add a "logical" component for responsiveness
        final resLogical = db.select(
          'SELECT SUM(LENGTH(requestId) + LENGTH(senderId) + LENGTH(payload) + 50) as s FROM packets',
        );
        int logical = 0;
        if (resLogical.isNotEmpty && resLogical.first['s'] != null) {
          logical = (resLogical.first['s'] as num).toInt();
        }

        return physical + (logical % 1024);
      }
    } catch (e) {
      Log.w('PacketStore', 'Error calculating storage size: $e');
    }
    return 0;
  }

  Future<List<StoredPacket>> getPacketsForRequest(
    String roomName,
    String requestId,
  ) async {
    final db = await _initDb(roomName);
    final result = db.select('SELECT * FROM packets WHERE requestId = ?', [
      requestId,
    ]);
    return result.map((row) => StoredPacket.fromMap(row)).toList();
  }

  Future<void> close() async {
    for (final db in _dbs.values) {
      db.dispose();
    }
    _dbs.clear();
  }
}
