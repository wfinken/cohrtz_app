import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cohortz/shared/security/encryption_service.dart';

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});
