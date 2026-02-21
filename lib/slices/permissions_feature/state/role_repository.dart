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
    if (db == null) return Stream.value([]);
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
    if (db == null) return;
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
    final db = _db;
    final roomName = _roomName;
    if (db == null || roomName == null) return;
    await _crdtService.delete(roomName, id, 'roles');
  }
}
