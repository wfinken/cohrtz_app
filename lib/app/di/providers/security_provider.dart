import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/shared/security/security_service.dart';
import 'secure_storage_provider.dart';

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService(
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
});
