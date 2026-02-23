import 'package:dart_mappable/dart_mappable.dart';

part 'user_model.mapper.dart';

@MappableClass()
class UserProfile with UserProfileMappable {
  final String id;
  final String displayName;
  final String publicKey;
  final String avatarBase64;
  final String avatarRef;
  final String bio;

  UserProfile({
    required this.id,
    required this.displayName,
    required this.publicKey,
    this.avatarBase64 = '',
    this.avatarRef = '',
    this.bio = '',
  });
}
