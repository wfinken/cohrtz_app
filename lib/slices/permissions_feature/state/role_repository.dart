import 'dart:convert';

import '../../../shared/database/database.dart';
import 'package:cohortz/slices/permissions_feature/models/role_model.dart';
import 'package:cohortz/slices/sync/runtime/crdt_service.dart';

class RoleRepository {
  final CrdtService _crdtService;
  final String? _roomName;

  RoleRepository(this._crdtService, this._roomName);

  AppDatabase? get _db =>
      _roomName != null ? _crdtService.getDatabase(_roomName) : null;

  Stream<List<Role>> watchRoles() {
    final db = _db;
    final roomName = _roomName;
    if (db == null) {
      if (roomName == null) return Stream.value([]);
      return _crdtService
          .watch(roomName, 'SELECT value FROM roles WHERE is_deleted = 0')
          .map((rows) {
            return rows
                .map((row) {
                  final jsonStr = row['value'] as String? ?? '';
                  if (jsonStr.isEmpty) return null;
                  try {
                    return RoleMapper.fromJson(jsonStr);
                  } catch (_) {
                    return null;
                  }
                })
                .whereType<Role>()
                .toList();
          });
    }
    return (db.select(
      db.roles,
    )..where((t) => t.isDeleted.equals(0))).watch().map((rows) {
      return rows.map((row) {
        final jsonStr = row.value;
        return RoleMapper.fromJson(jsonStr);
      }).toList();
    });
  }

  Future<void> saveRole(Role role) async {
    final db = _db;
    final roomName = _roomName;
    if (db == null) {
      if (roomName == null) return;
      await _crdtService.put(
        roomName,
        role.id,
        jsonEncode(role.toMap()),
        tableName: 'roles',
      );
      return;
    }
    await db
        .into(db.roles)
        .insertOnConflictUpdate(
          RoleEntity(
            id: role.id,
            value: jsonEncode(role.toMap()),
            isDeleted: 0,
          ),
        );
  }

  Future<void> deleteRole(String id) async {
    final roomName = _roomName;
    if (roomName == null) return;
    await _crdtService.delete(roomName, id, 'roles');
  }
}
