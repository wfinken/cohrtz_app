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
    final roomName = _roomName;
    if (db == null) {
      if (roomName == null) return Stream.value([]);
      return _crdtService
          .watch(
            roomName,
            'SELECT value FROM logical_groups WHERE is_deleted = 0',
          )
          .map((rows) {
            return rows
                .map((row) {
                  final value = row['value'] as String? ?? '';
                  if (value.isEmpty) return null;
                  try {
                    return LogicalGroupMapper.fromJson(value);
                  } catch (_) {
                    return null;
                  }
                })
                .whereType<LogicalGroup>()
                .where((group) => group.id != AclGroupIds.everyone)
                .toList();
          });
    }
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
    final roomName = _roomName;
    if (group.id == AclGroupIds.everyone) return;
    if (db == null) {
      if (roomName == null) return;
      await _crdtService.put(
        roomName,
        group.id,
        jsonEncode(group.toMap()),
        tableName: 'logical_groups',
      );
      return;
    }
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
    if (roomName == null || id == AclGroupIds.everyone) return;
    await _crdtService.delete(roomName, id, 'logical_groups');
  }
}
