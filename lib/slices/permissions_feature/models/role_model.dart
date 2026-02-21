import 'package:dart_mappable/dart_mappable.dart';

part 'role_model.mapper.dart';

@MappableClass()
class Role with RoleMappable {
  final String id;
  final String groupId;
  final String name;
  final int color;
  final int position;
  final int permissions;
  final bool isHoisted;

  Role({
    required this.id,
    required this.groupId,
    required this.name,
    required this.color,
    required this.position,
    required this.permissions,
    this.isHoisted = false,
  });
}
