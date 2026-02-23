import 'dart:convert';

import '../../../shared/database/database.dart';
import 'package:cohortz/slices/permissions_feature/models/member_model.dart';
import 'package:cohortz/slices/sync/runtime/crdt_service.dart';

class MemberRepository {
  final CrdtService _crdtService;
  final String? _roomName;

  MemberRepository(this._crdtService, this._roomName);

  AppDatabase? get _db =>
      _roomName != null ? _crdtService.getDatabase(_roomName) : null;

  Stream<List<GroupMember>> watchMembers() {
    final db = _db;
    final roomName = _roomName;
    if (db == null) {
      if (roomName == null) return Stream.value([]);
      return _crdtService
          .watch(roomName, 'SELECT value FROM members WHERE is_deleted = 0')
          .map((rows) {
            return rows
                .map((row) {
                  final jsonStr = row['value'] as String? ?? '';
                  if (jsonStr.isEmpty) return null;
                  try {
                    return GroupMemberMapper.fromJson(jsonStr);
                  } catch (_) {
                    return null;
                  }
                })
                .whereType<GroupMember>()
                .toList();
          });
    }
    return (db.select(
      db.members,
    )..where((t) => t.isDeleted.equals(0))).watch().map((rows) {
      return rows.map((row) {
        final jsonStr = row.value;
        return GroupMemberMapper.fromJson(jsonStr);
      }).toList();
    });
  }

  Future<void> saveMember(GroupMember member) async {
    final db = _db;
    final roomName = _roomName;
    if (db == null) {
      if (roomName == null) return;
      await _crdtService.put(
        roomName,
        member.id,
        jsonEncode(member.toMap()),
        tableName: 'members',
      );
      return;
    }
    await db
        .into(db.members)
        .insertOnConflictUpdate(
          MemberEntity(
            id: member.id,
            value: jsonEncode(member.toMap()),
            isDeleted: 0,
          ),
        );
  }

  Future<void> deleteMember(String id) async {
    final roomName = _roomName;
    if (roomName == null) return;
    await _crdtService.delete(roomName, id, 'members');
  }
}
