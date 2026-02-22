import 'package:dart_mappable/dart_mappable.dart';

part 'logical_group_model.mapper.dart';

@MappableClass()
class LogicalGroup with LogicalGroupMappable {
  final String id;
  final String name;
  final List<String> memberIds;
  final bool isSystem;

  const LogicalGroup({
    required this.id,
    required this.name,
    this.memberIds = const [],
    this.isSystem = false,
  });
}
