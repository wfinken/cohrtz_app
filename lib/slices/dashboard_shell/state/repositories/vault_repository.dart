import 'dart:convert';

import 'package:cohortz/shared/database/database.dart';
import 'package:cohortz/slices/dashboard_shell/models/dashboard_models.dart';
import 'package:cohortz/shared/utils/logging_service.dart';

import 'room_repository_base.dart';

abstract class IVaultRepository {
  Stream<List<VaultItem>> watchVaultItems();
  Future<void> saveVaultItem(VaultItem item);
  Future<void> deleteVaultItem(String id);
}

class VaultRepository extends RoomRepositoryBase implements IVaultRepository {
  const VaultRepository(super.crdtService, super.roomName);

  @override
  Stream<List<VaultItem>> watchVaultItems() {
    final activeDb = db;
    if (activeDb == null) return Stream.value([]);
    return (activeDb.select(
      activeDb.vaultItems,
    )..where((t) => t.isDeleted.equals(0))).watch().map((rows) {
      return rows
          .map((row) {
            try {
              return VaultItemMapper.fromJson(row.value);
            } catch (e) {
              Log.e('[VaultRepository]', 'Error decoding VaultItem', e);
              return null;
            }
          })
          .whereType<VaultItem>()
          .toList();
    });
  }

  @override
  Future<void> saveVaultItem(VaultItem item) async {
    final activeDb = db;
    if (activeDb == null) return;
    await activeDb
        .into(activeDb.vaultItems)
        .insertOnConflictUpdate(
          VaultItemEntity(
            id: item.id,
            value: jsonEncode(item.toMap()),
            isDeleted: 0,
          ),
        );
  }

  @override
  Future<void> deleteVaultItem(String id) => crdtDelete(id, 'vault_items');
}
