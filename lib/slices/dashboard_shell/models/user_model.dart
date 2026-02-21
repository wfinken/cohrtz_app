import 'package:dart_mappable/dart_mappable.dart';

part 'user_model.mapper.dart';

@MappableClass()
class UserProfile with UserProfileMappable {
  final String id;
  final String displayName;
  final String publicKey;

  UserProfile({
    required this.id,
    required this.displayName,
    required this.publicKey,
  });
}
