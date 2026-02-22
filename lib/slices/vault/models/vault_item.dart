import 'package:dart_mappable/dart_mappable.dart';
import 'package:cohortz/slices/permissions_core/acl_group_ids.dart';

part 'vault_item.mapper.dart';

@MappableClass()
class VaultItem with VaultItemMappable {
  final String id;
  final String label;
  final String type; // 'password', 'wifi', 'card', 'other'
  final String encryptedValue;
  final String creatorId;
  final List<String> visibilityGroupIds;

  VaultItem({
    required this.id,
    required this.label,
    required this.type,
    required this.encryptedValue,
    this.creatorId = '',
    this.visibilityGroupIds = const [AclGroupIds.everyone],
  });
}
