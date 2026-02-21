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
    if (db == null) return Stream.value([]);
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
    if (db == null) return;
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
    final db = _db;
    final roomName = _roomName;
    if (db == null || roomName == null) return;
    await _crdtService.delete(roomName, id, 'members');
  }
}
