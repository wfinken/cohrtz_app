import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/security_service.dart';

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});
