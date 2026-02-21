import 'package:dart_mappable/dart_mappable.dart';

part 'member_model.mapper.dart';

@MappableClass()
class GroupMember with GroupMemberMappable {
  final String id;
  final List<String> roleIds;

  GroupMember({required this.id, this.roleIds = const []});
}
