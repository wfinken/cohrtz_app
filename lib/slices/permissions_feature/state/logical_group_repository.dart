import 'dart:convert';

import 'package:cohortz/shared/database/database.dart';
import 'package:cohortz/slices/permissions_core/acl_group_ids.dart';
import 'package:cohortz/slices/permissions_feature/models/logical_group_model.dart';
import 'package:cohortz/slices/sync/runtime/crdt_service.dart';

class LogicalGroupRepository {
  final CrdtService _crdtService;
  final String? _roomName;

  LogicalGroupRepository(this._crdtService, this._roomName);

  AppDatabase? get _db =>
      _roomName != null ? _crdtService.getDatabase(_roomName) : null;

  Stream<List<LogicalGroup>> watchLogicalGroups() {
    final db = _db;
    if (db == null) return Stream.value([]);
    return (db.select(
      db.logicalGroups,
    )..where((t) => t.isDeleted.equals(0))).watch().map((rows) {
      return rows
          .map((row) {
            try {
              return LogicalGroupMapper.fromJson(row.value);
            } catch (_) {
              return null;
            }
          })
          .whereType<LogicalGroup>()
          .where((group) => group.id != AclGroupIds.everyone)
          .toList();
    });
  }

  Future<void> saveLogicalGroup(LogicalGroup group) async {
    final db = _db;
    if (db == null || group.id == AclGroupIds.everyone) return;
    await db
        .into(db.logicalGroups)
        .insertOnConflictUpdate(
          LogicalGroupEntity(
            id: group.id,
            value: jsonEncode(group.toMap()),
            isDeleted: 0,
          ),
        );
  }

  Future<void> deleteLogicalGroup(String id) async {
    final roomName = _roomName;
    final db = _db;
    if (db == null || roomName == null || id == AclGroupIds.everyone) return;
    await _crdtService.delete(roomName, id, 'logical_groups');
  }
}
