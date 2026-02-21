import 'package:dart_mappable/dart_mappable.dart';

part 'vault_item.mapper.dart';

@MappableClass()
class VaultItem with VaultItemMappable {
  final String id;
  final String label;
  final String type; // 'password', 'wifi', 'card', 'other'
  final String encryptedValue;
  final String creatorId;

  VaultItem({
    required this.id,
    required this.label,
    required this.type,
    required this.encryptedValue,
    this.creatorId = '',
  });
}
