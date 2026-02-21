import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/shared/security/group_identity_service.dart';

import 'security_provider.dart';

final groupIdentityServiceProvider = Provider<GroupIdentityService>((ref) {
  return GroupIdentityService(
    securityService: ref.read(securityServiceProvider),
  );
});
