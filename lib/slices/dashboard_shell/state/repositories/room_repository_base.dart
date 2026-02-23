import 'package:cohortz/shared/database/database.dart';
import 'package:cohortz/slices/sync/runtime/crdt_service.dart';

abstract class RoomRepositoryBase {
  final CrdtService crdtService;
  final String? roomName;

  const RoomRepositoryBase(this.crdtService, this.roomName);

  AppDatabase? get db =>
      roomName != null ? crdtService.getDatabase(roomName!) : null;

  Future<void> crdtDelete(String id, String tableName) async {
    final activeRoom = roomName;
    if (activeRoom == null) return;
    await crdtService.delete(activeRoom, id, tableName);
  }
}
