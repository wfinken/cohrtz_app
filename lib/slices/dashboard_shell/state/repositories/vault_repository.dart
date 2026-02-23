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
    final activeRoom = roomName;
    if (activeDb == null) {
      if (activeRoom == null) return Stream.value([]);
      return crdtService
          .watch(
            activeRoom,
            'SELECT value FROM vault_items WHERE is_deleted = 0',
          )
          .map((rows) {
            return rows
                .map((row) {
                  final value = row['value'] as String? ?? '';
                  if (value.isEmpty) return null;
                  try {
                    return VaultItemMapper.fromJson(value);
                  } catch (e) {
                    Log.e('[VaultRepository]', 'Error decoding VaultItem', e);
                    return null;
                  }
                })
                .whereType<VaultItem>()
                .toList();
          });
    }
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
    final activeRoom = roomName;
    if (activeDb == null) {
      if (activeRoom == null) return;
      await crdtService.put(
        activeRoom,
        item.id,
        jsonEncode(item.toMap()),
        tableName: 'vault_items',
      );
      return;
    }
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
